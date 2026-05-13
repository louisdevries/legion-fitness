import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

/// Service that tracks per-user achievement progress.
///
/// Public methods are "event hooks" — call them from the existing code
/// paths after relevant events happen. Each one is idempotent: calling
/// it twice with the same event won't unlock the same achievement twice.
///
/// Usage:
///   - After logging a set:
///       AchievementService.onSetLogged(exerciseId: 42, reps: 10);
///   - After saving daily steps:
///       AchievementService.onStepsLogged(date: today, steps: 12000);
///   - After completing an outdoor run:
///       AchievementService.onRunCompleted(distanceMeters: 5000);
///   - After completing a workout:
///       AchievementService.onWorkoutCompleted();
///   - After completing all weeks of a program:
///       AchievementService.onProgramCompleted();
///
/// All public methods return a list of newly-unlocked achievements so
/// the UI can show a celebration toast/snackbar if it wants.
class AchievementService {
  static final _supabase = Supabase.instance.client;

  // ===================================================================
  // EVENT HOOKS — call these from the relevant code paths.
  // ===================================================================

  /// Call after logging a completed set. Increments the user's running
  /// total reps for this exercise.
  static Future<List<UnlockedAchievement>> onSetLogged({
    required int exerciseId,
    required int reps,
  }) async {
    if (reps <= 0) return [];
    return _incrementAndCheck(
      type: 'exercise_reps',
      exerciseId: exerciseId,
      delta: reps,
    );
  }

  /// Call after the daily step total is updated. Stores the higher of
  /// (existing best day, today's count) in steps_daily, and recomputes
  /// the lifetime total in steps_total.
  static Future<List<UnlockedAchievement>> onStepsLogged({
    required int stepsToday,
  }) async {
    final unlocked = <UnlockedAchievement>[];

    // Daily-best: only increases if today beats the prior best.
    final dailyUnlocked = await _setAndCheckMax(
      type: 'steps_daily',
      newValue: stepsToday,
    );
    unlocked.addAll(dailyUnlocked);

    // Lifetime total: sum across all daily_steps rows.
    final lifetimeTotal = await _fetchLifetimeStepsTotal();
    if (lifetimeTotal != null) {
      final totalUnlocked = await _setAndCheckExact(
        type: 'steps_total',
        newValue: lifetimeTotal,
      );
      unlocked.addAll(totalUnlocked);
    }

    return unlocked;
  }

  /// Call after a completed outdoor run is saved. Bumps the run count
  /// and the total distance.
  static Future<List<UnlockedAchievement>> onRunCompleted({
    required double distanceMeters,
  }) async {
    final unlocked = <UnlockedAchievement>[];

    unlocked.addAll(await _incrementAndCheck(
      type: 'outdoor_runs',
      delta: 1,
    ));
    unlocked.addAll(await _incrementAndCheck(
      type: 'outdoor_distance',
      delta: distanceMeters.round(),
    ));

    return unlocked;
  }

  /// Call after a workout day is completed. Recomputes the user's current
  /// consecutive-day workout streak.
  static Future<List<UnlockedAchievement>> onWorkoutCompleted() async {
    final streak = await _computeCurrentStreak();
    return _setAndCheckExact(
      type: 'streak',
      newValue: streak,
    );
  }

  /// Call after a program is fully completed. Increments the count of
  /// programs completed.
  static Future<List<UnlockedAchievement>> onProgramCompleted() async {
    return _incrementAndCheck(
      type: 'program_complete',
      delta: 1,
    );
  }

  // ===================================================================
  // READ — used by the achievements screen.
  // ===================================================================

  /// Returns the full list of achievement rows for the current user
  /// from the user_achievement_progress view, ordered by status.
  static Future<List<AchievementRow>> fetchAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final rows = await _supabase
        .from('user_achievement_progress')
        .select()
    // Either the user's own row or unstarted definitions (user_id NULL).
        .or('user_id.eq.${user.id},user_id.is.null');

    return (rows as List)
        .map((r) => AchievementRow.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ===================================================================
  // INTERNAL — the actual update logic.
  // ===================================================================

  /// Increment-style update: the achievement value goes up by [delta].
  /// Used for cumulative things like total reps, distance, programs.
  static Future<List<UnlockedAchievement>> _incrementAndCheck({
    required String type,
    int? exerciseId,
    required int delta,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null || delta == 0) return [];

    try {
      // Get all tiers for this (type, exercise) so we know what to compare against.
      final defs = await _supabase
          .from('achievement_definitions')
          .select('id, tier, target_value')
          .eq('type', type)
          .filter(
        'exercise_id',
        exerciseId == null ? 'is' : 'eq',
        exerciseId,
      )
          .order('tier', ascending: true);

      final defList = List<Map<String, dynamic>>.from(defs as List);
      if (defList.isEmpty) return [];

      // All tiers share the same current_value for a given (user, type, exerciseId).
      // Read the existing value from tier 1 if present, else 0.
      final existing = await _supabase
          .from('user_achievements')
          .select('current_value')
          .eq('user_id', user.id)
          .eq('achievement_definition_id', defList.first['id'])
          .maybeSingle();

      final prevValue = (existing?['current_value'] as int?) ?? 0;
      final newValue = prevValue + delta;

      return _writeProgressAcrossTiers(
        userId: user.id,
        defs: defList,
        newValue: newValue,
        previousValue: prevValue,
      );
    } catch (e) {
      developer.log('Achievement _incrementAndCheck error: $e');
      return [];
    }
  }

  /// Max-style update: only updates if [newValue] is greater than the
  /// existing value. Used for "best day step count".
  static Future<List<UnlockedAchievement>> _setAndCheckMax({
    required String type,
    required int newValue,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final defs = await _supabase
        .from('achievement_definitions')
        .select('id, tier, target_value')
        .eq('type', type)
        .order('tier', ascending: true);

    final defList = List<Map<String, dynamic>>.from(defs as List);
    if (defList.isEmpty) return [];

    final existing = await _supabase
        .from('user_achievements')
        .select('current_value')
        .eq('user_id', user.id)
        .eq('achievement_definition_id', defList.first['id'])
        .maybeSingle();

    final prevValue = (existing?['current_value'] as int?) ?? 0;
    if (newValue <= prevValue) return [];

    return _writeProgressAcrossTiers(
      userId: user.id,
      defs: defList,
      newValue: newValue,
      previousValue: prevValue,
    );
  }

  /// Exact update: sets the value to [newValue] regardless of previous.
  /// Used for things derived from a query (lifetime steps, streak).
  static Future<List<UnlockedAchievement>> _setAndCheckExact({
    required String type,
    required int newValue,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final defs = await _supabase
        .from('achievement_definitions')
        .select('id, tier, target_value')
        .eq('type', type)
        .order('tier', ascending: true);

    final defList = List<Map<String, dynamic>>.from(defs as List);
    if (defList.isEmpty) return [];

    final existing = await _supabase
        .from('user_achievements')
        .select('current_value')
        .eq('user_id', user.id)
        .eq('achievement_definition_id', defList.first['id'])
        .maybeSingle();

    final prevValue = (existing?['current_value'] as int?) ?? 0;

    return _writeProgressAcrossTiers(
      userId: user.id,
      defs: defList,
      newValue: newValue,
      previousValue: prevValue,
    );
  }

  /// Writes the same current_value across every tier of an achievement
  /// group, and unlocks any tier whose target was just crossed.
  /// Returns the newly-unlocked tiers.
  static Future<List<UnlockedAchievement>> _writeProgressAcrossTiers({
    required String userId,
    required List<Map<String, dynamic>> defs,
    required int newValue,
    required int previousValue,
  }) async {
    final newlyUnlocked = <UnlockedAchievement>[];
    final now = DateTime.now().toIso8601String();

    for (final def in defs) {
      final defId = def['id'] as int;
      final target = (def['target_value'] as num).toInt();
      final justCrossed = previousValue < target && newValue >= target;

      await _supabase.from('user_achievements').upsert({
        'user_id': userId,
        'achievement_definition_id': defId,
        'current_value': newValue,
        'is_unlocked': newValue >= target,
        'unlocked_at': justCrossed ? now : null,
        'updated_at': now,
      }, onConflict: 'user_id,achievement_definition_id');

      if (justCrossed) {
        // Fetch label/description for the celebration toast.
        final meta = await _supabase
            .from('achievement_definitions')
            .select('label, description, tier')
            .eq('id', defId)
            .single();
        newlyUnlocked.add(UnlockedAchievement(
          definitionId: defId,
          label: meta['label'] as String,
          description: meta['description'] as String,
          tier: (meta['tier'] as num).toInt(),
        ));
      }
    }

    return newlyUnlocked;
  }

  // -------------------- helpers --------------------

  static Future<int?> _fetchLifetimeStepsTotal() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
      // Postgres SUM via Supabase RPC is overkill — fetch and sum locally.
      final rows = await _supabase
          .from('daily_steps')
          .select('steps')
          .eq('user_id', user.id);
      int total = 0;
      for (final r in rows as List) {
        total += ((r['steps'] as num?)?.toInt() ?? 0);
      }
      return total;
    } catch (e) {
      developer.log('Lifetime steps fetch error: $e');
      return null;
    }
  }

  /// Look at exercise_completions, group by date, count the longest
  /// run of consecutive days ending today (or yesterday, to be lenient).
  static Future<int> _computeCurrentStreak() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;
    try {
      final rows = await _supabase
          .from('exercise_completions')
          .select('completed_at')
          .eq('user_id', user.id);

      final dates = <DateTime>{};
      for (final r in rows as List) {
        final s = r['completed_at'] as String?;
        if (s == null) continue;
        final dt = DateTime.parse(s);
        dates.add(DateTime(dt.year, dt.month, dt.day));
      }
      if (dates.isEmpty) return 0;

      // Walk back from today, counting consecutive days.
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      var cursor = dates.contains(todayDate)
          ? todayDate
          : todayDate.subtract(const Duration(days: 1));
      if (!dates.contains(cursor)) return 0;

      int streak = 0;
      while (dates.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return streak;
    } catch (e) {
      developer.log('Streak compute error: $e');
      return 0;
    }
  }
}

// ===================================================================
// Models
// ===================================================================

class UnlockedAchievement {
  final int definitionId;
  final String label;
  final String description;
  final int tier;

  UnlockedAchievement({
    required this.definitionId,
    required this.label,
    required this.description,
    required this.tier,
  });
}

class AchievementRow {
  final int definitionId;
  final String type;
  final int? exerciseId;
  final String? exerciseName;
  final int tier;
  final int targetValue;
  final String label;
  final String description;
  final String? icon;
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  AchievementRow({
    required this.definitionId,
    required this.type,
    required this.exerciseId,
    required this.exerciseName,
    required this.tier,
    required this.targetValue,
    required this.label,
    required this.description,
    required this.icon,
    required this.currentValue,
    required this.isUnlocked,
    required this.unlockedAt,
  });

  factory AchievementRow.fromMap(Map<String, dynamic> m) {
    return AchievementRow(
      definitionId: (m['definition_id'] as num).toInt(),
      type: m['type'] as String,
      exerciseId: (m['exercise_id'] as num?)?.toInt(),
      exerciseName: m['exercise_name'] as String?,
      tier: (m['tier'] as num).toInt(),
      targetValue: (m['target_value'] as num).toInt(),
      label: m['label'] as String,
      description: m['description'] as String,
      icon: m['icon'] as String?,
      currentValue: (m['current_value'] as num?)?.toInt() ?? 0,
      isUnlocked: m['is_unlocked'] as bool? ?? false,
      unlockedAt: m['unlocked_at'] == null
          ? null
          : DateTime.parse(m['unlocked_at'] as String),
    );
  }

  /// 0.0 → 1.0 (clamped). Useful for progress bars.
  double get progress {
    if (targetValue == 0) return 0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  /// Categorisation for the three-section UI.
  /// - Completed: hit the target
  /// - InProgress: started but not finished
  /// - Locked: 0 progress
  AchievementStatus get status {
    if (isUnlocked) return AchievementStatus.completed;
    if (currentValue > 0) return AchievementStatus.inProgress;
    return AchievementStatus.locked;
  }
}

enum AchievementStatus { completed, inProgress, locked }