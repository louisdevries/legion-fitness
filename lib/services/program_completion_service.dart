import 'package:supabase_flutter/supabase_flutter.dart';

/// Single source of truth for "what's completed / what's next" in a
/// program. Both the home screen and the week/day selector read from
/// this instead of each maintaining their own (subtly different)
/// completion logic.
class ProgramCompletionData {
  final int totalWeeks;
  final int daysPerWeek;
  final Map<int, Set<int>> completedDaysByWeek;
  final int highestUnlockedWeek;
  final int? nextWeek;
  final int? nextDay;
  final Set<String> workoutDates;

  ProgramCompletionData({
    required this.totalWeeks,
    required this.daysPerWeek,
    required this.completedDaysByWeek,
    required this.highestUnlockedWeek,
    required this.nextWeek,
    required this.nextDay,
    required this.workoutDates,
  });

  bool isDayCompleted(int week, int day) =>
      completedDaysByWeek[week]?.contains(day) ?? false;
}

class ProgramCompletionService {
  static final _supabase = Supabase.instance.client;

  static Future<ProgramCompletionData> load(int programId) async {
    final userId = _supabase.auth.currentUser?.id;

    final programData = await _supabase
        .from('fitness_programs')
        .select('weeks')
        .eq('id', programId)
        .maybeSingle();
    final totalWeeks = programData?['weeks'] as int? ?? 6;

    // Most programs only have week 1 rows in program_exercises and reuse
    // week 1's day structure via auto-progression. Some (e.g. Greek
    // Warrior) define every week explicitly, and a later week can have
    // more exercises per day than week 1 — so fetch every week's rows and
    // use each week's own count when it has one, falling back to week 1
    // only for weeks with no explicit rows.
    final allRows = await _supabase
        .from('program_exercises')
        .select('id, week_number, day_number, exercise_id')
        .eq('program_id', programId);

    final peIds = (allRows as List).map((r) => r['id'] as int).toList();

    final detailRows = peIds.isEmpty
        ? []
        : await _supabase
            .from('program_exercise_details')
            .select('program_exercise_id, superset_exercise_id')
            .inFilter('program_exercise_id', peIds);

    final Map<int, int?> supersetByPeId = {
      for (final d in detailRows)
        d['program_exercise_id'] as int: d['superset_exercise_id'] as int?,
    };

    // Required exercise IDs per (week, day) — includes superset partners,
    // since those are logged as separate exercise_completions rows too.
    final Map<int, Map<int, Set<int>>> requiredExerciseIdsByWeekDay = {};
    for (final row in allRows) {
      final week = row['week_number'] as int;
      final day = row['day_number'] as int;
      final exerciseId = row['exercise_id'] as int;
      final peId = row['id'] as int;
      final required = requiredExerciseIdsByWeekDay
          .putIfAbsent(week, () => {})
          .putIfAbsent(day, () => {});
      required.add(exerciseId);
      final supersetId = supersetByPeId[peId];
      if (supersetId != null) required.add(supersetId);
    }

    final requiredExerciseIdsByDay = requiredExerciseIdsByWeekDay[1] ?? {};
    final daysPerWeek = requiredExerciseIdsByDay.keys.length;

    Set<int> requiredExerciseIdsFor(int week, int day) =>
        requiredExerciseIdsByWeekDay[week]?[day] ??
        requiredExerciseIdsByDay[day] ??
        {};

    if (userId == null || requiredExerciseIdsByDay.isEmpty) {
      return ProgramCompletionData(
        totalWeeks: totalWeeks,
        daysPerWeek: daysPerWeek,
        completedDaysByWeek: {},
        highestUnlockedWeek: 1,
        nextWeek: requiredExerciseIdsByDay.isEmpty ? null : 1,
        nextDay: requiredExerciseIdsByDay.isEmpty
            ? null
            : (requiredExerciseIdsByDay.keys.toList()..sort()).first,
        workoutDates: {},
      );
    }

    final completionLogs = await _supabase
        .from('exercise_completions')
        .select('week_number, day_number, exercise_id, completed_at')
        .eq('program_id', programId)
        .eq('user_id', userId);

    final Map<String, Set<int>> completedExerciseIdsByDay = {};
    for (final log in completionLogs) {
      final week = (log['week_number'] as num?)?.toInt();
      final day = (log['day_number'] as num?)?.toInt();
      final exerciseId = (log['exercise_id'] as num?)?.toInt();
      if (week == null || day == null || exerciseId == null) continue;
      completedExerciseIdsByDay
          .putIfAbsent('$week-$day', () => {})
          .add(exerciseId);
    }

    final Map<int, Set<int>> completedDaysByWeek = {};
    for (int week = 1; week <= totalWeeks; week++) {
      for (final day in requiredExerciseIdsByDay.keys) {
        final required = requiredExerciseIdsFor(week, day);
        final completed = completedExerciseIdsByDay['$week-$day'] ?? {};
        if (required.isNotEmpty && completed.length >= required.length) {
          completedDaysByWeek.putIfAbsent(week, () => {}).add(day);
        }
      }
    }

    // A week is unlocked once every day of the previous week is complete.
    final allDays = requiredExerciseIdsByDay.keys.toSet();
    int highestUnlockedWeek = 1;
    for (int week = 1; week <= totalWeeks; week++) {
      final completed = completedDaysByWeek[week] ?? {};
      if (allDays.isNotEmpty && allDays.every(completed.contains)) {
        highestUnlockedWeek = week + 1;
      } else {
        break;
      }
    }
    highestUnlockedWeek = highestUnlockedWeek.clamp(1, totalWeeks);

    // First incomplete day, scanning weeks/days in order.
    int? nextWeek;
    int? nextDay;
    final sortedDays = requiredExerciseIdsByDay.keys.toList()..sort();
    outer:
    for (int week = 1; week <= totalWeeks; week++) {
      final completed = completedDaysByWeek[week] ?? {};
      for (final day in sortedDays) {
        if (!completed.contains(day)) {
          nextWeek = week;
          nextDay = day;
          break outer;
        }
      }
    }

    // Only count a calendar date as a workout day if the full day was
    // completed on it (partial sessions excluded).
    final Set<String> workoutDates = {};
    for (final log in completionLogs) {
      final week = (log['week_number'] as num?)?.toInt();
      final day = (log['day_number'] as num?)?.toInt();
      if (week == null || day == null) continue;
      if (completedDaysByWeek[week]?.contains(day) == true &&
          log['completed_at'] != null) {
        final date = DateTime.parse(log['completed_at']);
        workoutDates.add(date.toIso8601String().substring(0, 10));
      }
    }

    return ProgramCompletionData(
      totalWeeks: totalWeeks,
      daysPerWeek: daysPerWeek,
      completedDaysByWeek: completedDaysByWeek,
      highestUnlockedWeek: highestUnlockedWeek,
      nextWeek: nextWeek,
      nextDay: nextDay,
      workoutDates: workoutDates,
    );
  }
}
