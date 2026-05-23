import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

/// Service for managing XP and levels.
///
/// XP is stored as a ledger in xp_events. Total XP is the SUM of all
/// events for the user. Level is derived from total XP via formula
/// — never stored, always computed.
///
/// Idempotency: every XP grant uses a unique source_key so retries
/// or duplicate calls don't double-grant.
class XpService {
  static final _supabase = Supabase.instance.client;

  // ===================================================================
  // XP VALUES (tune these as you balance the game feel)
  // ===================================================================

  static const _xpWorkout = 50;
  static const _xpSteps5k = 10;
  static const _xpSteps10k = 25;
  static const _xpRunBase = 30;
  static const _xpRun5km = 50; // on top of base
  static const _xpProgramComplete = 500;

  // Achievement XP scales with tier
  static const _xpAchievementByTier = {
    1: 50,
    2: 100,
    3: 200,
    4: 400,
    5: 800,
  };

  // Streak XP scales with milestone (must match achievement streak tiers)
  static const _xpStreakByDays = {
    3: 100,
    7: 250,
    30: 500,
    100: 1000,
  };

  // ===================================================================
  // LEVEL MATH
  // ===================================================================

  /// XP required to GO from level n-1 to level n.
  /// Cumulative: 100, 300, 600, 1000, 1500, 2100, ...
  /// (using 100 * n * (n+1) / 2 as the total XP to reach level n+1)
  static int xpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    final n = level - 1;
    return 100 * n * (n + 1) ~/ 2;
  }

  /// What level corresponds to a given total XP value.
  static int levelFromXp(int totalXp) {
    if (totalXp < 100) return 1;
    int level = 1;
    while (xpRequiredForLevel(level + 1) <= totalXp) {
      level++;
      if (level > 100) break; // safety cap
    }
    return level;
  }

  /// Progress through the current level: (xpIntoLevel, xpForLevel).
  /// Example: at 250 XP → level 2 (which started at 100, level 3 needs 300)
  /// → returns (150, 200) meaning 150 / 200 XP into level 2.
  static ({int xpInto, int xpFor}) progressInLevel(int totalXp) {
    final level = levelFromXp(totalXp);
    final start = xpRequiredForLevel(level);
    final next = xpRequiredForLevel(level + 1);
    return (xpInto: totalXp - start, xpFor: next - start);
  }

  // ===================================================================
  // EVENT HOOKS — call these alongside achievement hooks
  // ===================================================================

  /// After a workout day is fully completed.
  static Future<List<XpGrant>> onWorkoutCompleted({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    return _grant(
      sourceType: 'workout',
      sourceKey: 'workout:$programId:$weekNumber:$dayNumber',
      amount: _xpWorkout,
      label: 'Workout complete',
    );
  }

  /// After daily steps are synced. Grants XP for each threshold crossed today.
  /// Idempotent per day per threshold.
  static Future<List<XpGrant>> onStepsLogged({
    required int stepsToday,
  }) async {
    final grants = <XpGrant>[];
    final dateKey = _todayKey();

    if (stepsToday >= 5000) {
      grants.addAll(await _grant(
        sourceType: 'steps_daily',
        sourceKey: 'steps_5k:$dateKey',
        amount: _xpSteps5k,
        label: '5,000 steps today',
      ));
    }
    if (stepsToday >= 10000) {
      grants.addAll(await _grant(
        sourceType: 'steps_daily',
        sourceKey: 'steps_10k:$dateKey',
        amount: _xpSteps10k,
        label: '10,000 steps today',
      ));
    }
    return grants;
  }

  /// After an outdoor run is saved.
  static Future<List<XpGrant>> onRunCompleted({
    required int runId,
    required double distanceMeters,
  }) async {
    final grants = <XpGrant>[];

    if (distanceMeters >= 1000) {
      grants.addAll(await _grant(
        sourceType: 'run',
        sourceKey: 'run:$runId',
        amount: _xpRunBase,
        label: 'Outdoor run completed',
      ));
    }
    if (distanceMeters >= 5000) {
      grants.addAll(await _grant(
        sourceType: 'run_5km',
        sourceKey: 'run_5km:$runId',
        amount: _xpRun5km,
        label: '5km milestone',
      ));
    }
    return grants;
  }

  /// After an achievement is unlocked. Called from AchievementService.
  static Future<List<XpGrant>> onAchievementUnlocked({
    required int definitionId,
    required int tier,
    required String achievementLabel,
  }) async {
    final amount = _xpAchievementByTier[tier] ?? 50;
    return _grant(
      sourceType: 'achievement',
      sourceKey: 'achievement:$definitionId',
      amount: amount,
      label: 'Unlocked $achievementLabel',
    );
  }

  /// After a streak hits a milestone day count.
  static Future<List<XpGrant>> onStreakMilestone({
    required int streakDays,
  }) async {
    final amount = _xpStreakByDays[streakDays];
    if (amount == null) return [];

    final dateKey = _todayKey();
    return _grant(
      sourceType: 'streak',
      sourceKey: 'streak:${streakDays}d:$dateKey',
      amount: amount,
      label: '$streakDays-day streak',
    );
  }

  /// After a program is completed (all weeks + days done).
  static Future<List<XpGrant>> onProgramCompleted({
    required int programId,
  }) async {
    return _grant(
      sourceType: 'program_complete',
      sourceKey: 'program:$programId',
      amount: _xpProgramComplete,
      label: 'Program complete',
    );
  }

  // ===================================================================
  // READS
  // ===================================================================

  /// Returns the user's total XP and derived level info.
  static Future<XpSummary> fetchSummary() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const XpSummary.empty();

    try {
      final row = await _supabase
          .from('user_xp_totals')
          .select('total_xp')
          .eq('user_id', user.id)
          .maybeSingle();

      final total = (row?['total_xp'] as num?)?.toInt() ?? 0;
      return XpSummary.fromTotal(total);
    } catch (e) {
      developer.log('XP summary error: $e');
      return const XpSummary.empty();
    }
  }

  /// Recent XP grants, newest first.
  static Future<List<XpEvent>> fetchRecent({int limit = 10}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _supabase
          .from('xp_events')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((r) => XpEvent.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('XP recent fetch error: $e');
      return [];
    }
  }

  // ===================================================================
  // INTERNAL
  // ===================================================================

  /// Tries to insert an xp_events row. If the unique constraint blocks
  /// it (already granted), returns empty. Otherwise returns the grant
  /// info for the caller to surface.
  static Future<List<XpGrant>> _grant({
    required String sourceType,
    required String sourceKey,
    required int amount,
    required String label,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    if (amount <= 0) return [];

    try {
      // Capture level BEFORE the grant so we can detect level-ups.
      final beforeSummary = await fetchSummary();
      final beforeLevel = beforeSummary.level;

      // upsert with ignoreDuplicates skips the row if the unique key
      // conflict happens — returns empty list in that case.
      final inserted = await _supabase
          .from('xp_events')
          .upsert({
        'user_id': user.id,
        'source_type': sourceType,
        'source_key': sourceKey,
        'amount': amount,
        'label': label,
      }, onConflict: 'user_id,source_key', ignoreDuplicates: true)
          .select();

      if ((inserted as List).isEmpty) {
        // Already granted before, no-op.
        return [];
      }

      // Check if this grant pushed them up a level.
      final afterSummary = await fetchSummary();
      final levelUps = <int>[];
      for (int lvl = beforeLevel + 1; lvl <= afterSummary.level; lvl++) {
        levelUps.add(lvl);
      }

      return [
        XpGrant(
          amount: amount,
          label: label,
          newTotal: afterSummary.totalXp,
          newLevel: afterSummary.level,
          leveledUpTo: levelUps,
        ),
      ];
    } catch (e) {
      developer.log('XP grant error ($sourceKey): $e');
      return [];
    }
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}

// =====================================================================
// MODELS
// =====================================================================

class XpSummary {
  final int totalXp;
  final int level;
  final int xpIntoLevel;
  final int xpForLevel;

  const XpSummary({
    required this.totalXp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForLevel,
  });

  const XpSummary.empty()
      : totalXp = 0,
        level = 1,
        xpIntoLevel = 0,
        xpForLevel = 100;

  factory XpSummary.fromTotal(int total) {
    final level = XpService.levelFromXp(total);
    final start = XpService.xpRequiredForLevel(level);
    final next = XpService.xpRequiredForLevel(level + 1);
    return XpSummary(
      totalXp: total,
      level: level,
      xpIntoLevel: total - start,
      xpForLevel: next - start,
    );
  }

  double get progress => xpForLevel == 0 ? 0 : xpIntoLevel / xpForLevel;
}

class XpEvent {
  final int id;
  final String sourceType;
  final String sourceKey;
  final int amount;
  final String label;
  final DateTime createdAt;

  XpEvent({
    required this.id,
    required this.sourceType,
    required this.sourceKey,
    required this.amount,
    required this.label,
    required this.createdAt,
  });

  factory XpEvent.fromMap(Map<String, dynamic> m) {
    return XpEvent(
      id: (m['id'] as num).toInt(),
      sourceType: m['source_type'] as String,
      sourceKey: m['source_key'] as String,
      amount: (m['amount'] as num).toInt(),
      label: m['label'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

class XpGrant {
  final int amount;
  final String label;
  final int newTotal;
  final int newLevel;
  final List<int> leveledUpTo;

  XpGrant({
    required this.amount,
    required this.label,
    required this.newTotal,
    required this.newLevel,
    required this.leveledUpTo,
  });

  bool get isLevelUp => leveledUpTo.isNotEmpty;
}