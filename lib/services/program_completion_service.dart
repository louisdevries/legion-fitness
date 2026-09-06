import 'package:supabase_flutter/supabase_flutter.dart';
import 'cardio_day_service.dart';

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

    Set<int> requiredExerciseIdsFor(int week, int day) =>
        requiredExerciseIdsByWeekDay[week]?[day] ??
        requiredExerciseIdsByDay[day] ??
        {};

    // Cardio days (pure outdoor-run days) live in program_days, not
    // program_exercises — they have no exercises to complete, just a
    // cardio_day_completions row. Same per-week-explicit-with-week-1-
    // fallback shape as workout days above.
    final programDaysByKey = await CardioDayService.fetchProgramDays(programId);
    final Map<int, Set<int>> cardioDaysByWeek = {};
    for (final pd in programDaysByKey.values) {
      if (!pd.isCardio) continue;
      cardioDaysByWeek.putIfAbsent(pd.weekNumber, () => {}).add(pd.dayNumber);
    }
    final week1CardioDays = cardioDaysByWeek[1] ?? {};
    Set<int> cardioDaysFor(int week) =>
        cardioDaysByWeek[week] ?? week1CardioDays;

    Set<int> allDaysFor(int week) {
      final workoutDays =
          requiredExerciseIdsByWeekDay[week]?.keys.toSet() ??
              requiredExerciseIdsByDay.keys.toSet();
      return workoutDays.union(cardioDaysFor(week));
    }

    final daysPerWeek = allDaysFor(1).length;

    if (userId == null || daysPerWeek == 0) {
      final firstWeekDays = allDaysFor(1).toList()..sort();
      return ProgramCompletionData(
        totalWeeks: totalWeeks,
        daysPerWeek: daysPerWeek,
        completedDaysByWeek: {},
        highestUnlockedWeek: 1,
        nextWeek: firstWeekDays.isEmpty ? null : 1,
        nextDay: firstWeekDays.isEmpty ? null : firstWeekDays.first,
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

    // Cardio days: complete when a cardio_day_completions row exists,
    // independent of exercise_completions (they have no exercises).
    final completedCardioKeys =
        await CardioDayService.fetchCompletedCardioKeys(programId);

    final Map<int, Set<int>> completedDaysByWeek = {};
    for (int week = 1; week <= totalWeeks; week++) {
      for (final day in allDaysFor(week)) {
        if (cardioDaysFor(week).contains(day)) {
          if (completedCardioKeys.contains('$week-$day')) {
            completedDaysByWeek.putIfAbsent(week, () => {}).add(day);
          }
          continue;
        }
        final required = requiredExerciseIdsFor(week, day);
        final completed = completedExerciseIdsByDay['$week-$day'] ?? {};
        if (required.isNotEmpty && completed.length >= required.length) {
          completedDaysByWeek.putIfAbsent(week, () => {}).add(day);
        }
      }
    }

    // A week is unlocked once every day of the previous week is complete.
    int highestUnlockedWeek = 1;
    for (int week = 1; week <= totalWeeks; week++) {
      final required = allDaysFor(week);
      final completed = completedDaysByWeek[week] ?? {};
      if (required.isNotEmpty && required.every(completed.contains)) {
        highestUnlockedWeek = week + 1;
      } else {
        break;
      }
    }
    highestUnlockedWeek = highestUnlockedWeek.clamp(1, totalWeeks);

    // First incomplete day, scanning weeks/days in order.
    int? nextWeek;
    int? nextDay;
    outer:
    for (int week = 1; week <= totalWeeks; week++) {
      final completed = completedDaysByWeek[week] ?? {};
      final sortedDays = allDaysFor(week).toList()..sort();
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
