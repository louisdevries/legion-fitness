import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_state.dart';
import 'dart:developer' as developer;

class HomeService {
  final supabase = Supabase.instance.client;

  Future<HomeState> loadHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    final programId = prefs.getInt('active_program_id');

    if (programId == null) {
      return HomeState(isLoading: false);
    }

    final programInfo = await _loadProgramInfo(programId);
    final progressData = await _loadProgress(programId);

    await prefs.setInt('active_week_number', progressData.currentWeek);

    return HomeState(
      programId: programId,
      currentWeek: progressData.currentWeek,
      programName: programInfo['name'],
      programImage: programInfo['image'],
      completedDays: progressData.completedDays,
      completedWorkoutDates: progressData.completedWorkoutDates,
      nextWeek: progressData.nextWeek,
      nextDay: progressData.nextDay,
      programProgress: progressData.programProgress,
      weekProgress: progressData.weekProgress,
      isLoading: false,
    );
  }

  Future<Map<String, String?>> _loadProgramInfo(int programId) async {
    final data = await supabase
        .from('fitness_programs')
        .select('name, image_url')
        .eq('id', programId)
        .maybeSingle();

    return {
      'name': data?['name'] as String?,
      'image': data?['image_url'] as String?,
    };
  }

  Future<_ProgressData> _loadProgress(int programId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        developer.log("No user logged in");
        return _ProgressData();
      }

      final allExercisesData = await supabase
          .from('program_exercises')
          .select('id, week_number, day_number')
          .eq('program_id', programId)
          .order('week_number', ascending: true)
          .order('day_number', ascending: true);

      if ((allExercisesData as List).isEmpty) {
        developer.log("No exercises found for program $programId");
        return _ProgressData();
      }

      final allExercises = (allExercisesData)
          .map((e) => {
                'id': e['id'],
                'week': (e['week_number'] as num).toInt(),
                'day': (e['day_number'] as num).toInt(),
              })
          .toList();

      developer.log("Total exercises in program: ${allExercises.length}");

      final exerciseDistribution = _getExerciseDistribution(allExercises);
      developer.log("Exercise distribution by week/day: $exerciseDistribution");

      final exercisesByDay = _groupExercisesByDay(allExercises);
      developer.log("Exercise groups: ${exercisesByDay.keys.toList()}");

      // FIX: fetch exercise_id so we can deduplicate by exercise, not by row
      final completedLogsData = await supabase
          .from('exercise_completions')
          .select('week_number, day_number, exercise_id, completed_at')
          .eq('user_id', user.id)
          .eq('program_id', programId);

      final completionData = _analyzeCompletionData(
        completedLogsData as List,
        exercisesByDay,
      );

      developer.log("=== RAW DATA DEBUG ===");
      developer.log("Total logs fetched: ${completedLogsData.length}");
      developer.log("Completed count by day: ${completionData.countByDay}");
      developer.log("Unique workout dates: ${completionData.workoutDates}");

      final nextWorkout = await _findNextWorkout(
        exercisesByDay: exercisesByDay,
        completedCountByDay: completionData.countByDay,
        programId: programId,
      );

      final progressMetrics = await _calculateProgress(
        programId: programId,
        exercisesByDay: exercisesByDay,
        completedCountByDay: completionData.countByDay,
        completedWorkoutsByWeek: completionData.completedByWeek,
        currentWeek: nextWorkout.week ?? 1,
        workoutDates: completionData.workoutDates,
      );

      developer.log("=== PROGRESS DEBUG ===");
      developer.log(
          "Next workout -> Week: ${nextWorkout.week}, Day: ${nextWorkout.day}");
      developer.log("Current week (program): ${progressMetrics.currentWeek}");
      developer.log(
          "This calendar week completed days: ${progressMetrics.completedDays}");
      developer.log(
          "Program progress: ${(progressMetrics.programProgress * 100).toInt()}%");

      return _ProgressData(
        currentWeek: progressMetrics.currentWeek,
        nextWeek: nextWorkout.week,
        nextDay: nextWorkout.day,
        completedDays: progressMetrics.completedDays,
        completedWorkoutDates: completionData.workoutDates,
        programProgress: progressMetrics.programProgress,
        weekProgress: progressMetrics.weekProgress,
      );
    } catch (e, stack) {
      developer.log("ERROR in _loadProgress", error: e, stackTrace: stack);
      return _ProgressData();
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupExercisesByDay(
      List<Map<String, dynamic>> exercises) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final e in exercises) {
      final key = "${e['week']}-${e['day']}";
      grouped.putIfAbsent(key, () => []).add(e);
    }
    return grouped;
  }

  Map<int, Map<int, int>> _getExerciseDistribution(
      List<Map<String, dynamic>> exercises) {
    final Map<int, Map<int, int>> distribution = {};
    for (final e in exercises) {
      final week = e['week'] as int;
      final day = e['day'] as int;
      distribution.putIfAbsent(week, () => {});
      distribution[week]![day] = (distribution[week]![day] ?? 0) + 1;
    }
    return distribution;
  }

  _CompletionData _analyzeCompletionData(
    List logs,
    Map<String, List<Map<String, dynamic>>> exercisesByDay,
  ) {
    // FIX: use Set<int> per day to count UNIQUE exercises completed,
    // not raw rows — because each exercise now has multiple set rows.
    // A day is complete when every exercise_id has at least one logged set.
    final Map<String, Set<int>> completedExercisesByDay = {};
    final Set<String> workoutDates = {};

    for (final log in logs) {
      final week = (log['week_number'] as num?)?.toInt();
      final day = (log['day_number'] as num?)?.toInt();
      final exerciseId = (log['exercise_id'] as num?)?.toInt();

      if (week == null || day == null || exerciseId == null) continue;

      final key = "$week-$day";

      // Add exercise_id to the set — duplicates (multiple sets) are ignored
      // because Set only keeps unique values. This is correct: we want to
      // know "did the user do this exercise at all", not "how many sets".
      completedExercisesByDay.putIfAbsent(key, () => <int>{});
      completedExercisesByDay[key]!.add(exerciseId);

      if (log['completed_at'] != null) {
        final date = DateTime.parse(log['completed_at']);
        workoutDates.add(date.toIso8601String().substring(0, 10));
      }
    }

    // countByDay = number of UNIQUE exercises completed per day
    final Map<String, int> countByDay = {
      for (final e in completedExercisesByDay.entries) e.key: e.value.length
    };

    final Map<int, Set<int>> completedByWeek = {};

    countByDay.forEach((key, completedCount) {
      final exercises = exercisesByDay[key];
      final total = exercises?.length ?? 0;

      // Day is complete when all exercises have been touched
      if (total > 0 && completedCount >= total) {
        final parts = key.split('-');
        final week = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        completedByWeek.putIfAbsent(week, () => {}).add(day);
      }
    });

    return _CompletionData(
      countByDay: countByDay,
      firstCompletionByDay: {},
      workoutDates: workoutDates,
      completedByWeek: completedByWeek,
    );
  }

  Future<_NextWorkout> _findNextWorkout({
    required Map<String, List<Map<String, dynamic>>> exercisesByDay,
    required Map<String, int> completedCountByDay,
    required int programId,
  }) async {
    int? nextWeek;
    int? nextDay;

    final sortedKeys = exercisesByDay.keys.toList()
      ..sort((a, b) {
        final aParts = a.split('-').map(int.parse).toList();
        final bParts = b.split('-').map(int.parse).toList();
        if (aParts[0] != bParts[0]) return aParts[0] - bParts[0];
        return aParts[1] - bParts[1];
      });

    developer.log("Checking workout days in order: $sortedKeys");

    for (final key in sortedKeys) {
      final exercises = exercisesByDay[key]!;
      final completed = completedCountByDay[key] ?? 0;
      final isComplete = completed >= exercises.length;

      developer.log(
          "  $key: ${exercises.length} exercises, $completed completed, complete=$isComplete");

      if (!isComplete) {
        final parts = key.split('-');
        nextWeek = int.parse(parts[0]);
        nextDay = int.parse(parts[1]);
        developer.log(
            "  -> Found incomplete workout: Week $nextWeek, Day $nextDay");
        break;
      }
    }

    if (nextWeek == null) {
      developer.log("Week 1 is complete. Checking for next week...");

      final programData = await supabase
          .from('fitness_programs')
          .select('weeks')
          .eq('id', programId)
          .maybeSingle();

      final totalWeeks = programData?['weeks'] as int? ?? 6;
      developer.log("Program has $totalWeeks total weeks");

      int highestCompletedWeek = 1;
      final weekPattern = RegExp(r'^(\d+)-\d+$');
      for (final key in completedCountByDay.keys) {
        final match = weekPattern.firstMatch(key);
        if (match != null) {
          final week = int.parse(match.group(1)!);
          if (week > highestCompletedWeek) {
            highestCompletedWeek = week;
          }
        }
      }

      developer.log("Highest week with any completion: $highestCompletedWeek");

      final daysPerWeek =
          exercisesByDay.keys.where((k) => k.startsWith('1-')).length;
      developer.log("Days per week: $daysPerWeek");

      int completedDaysInHighestWeek = 0;
      for (int day = 1; day <= daysPerWeek; day++) {
        final key = '$highestCompletedWeek-$day';
        final completed = completedCountByDay[key] ?? 0;
        if (completed > 0) {
          completedDaysInHighestWeek++;
        }
      }

      developer.log(
          "Completed days in week $highestCompletedWeek: $completedDaysInHighestWeek/$daysPerWeek");

      if (completedDaysInHighestWeek >= daysPerWeek) {
        if (highestCompletedWeek < totalWeeks) {
          nextWeek = highestCompletedWeek + 1;
          nextDay = 1;
          developer
              .log("  -> Moving to next week: Week $nextWeek, Day $nextDay");
        } else {
          developer.log("  -> Program completed!");
        }
      } else {
        for (int day = 1; day <= daysPerWeek; day++) {
          final key = '$highestCompletedWeek-$day';
          final completed = completedCountByDay[key] ?? 0;
          if (completed == 0) {
            nextWeek = highestCompletedWeek;
            nextDay = day;
            developer.log(
                "  -> Found incomplete day in week $highestCompletedWeek: Day $nextDay");
            break;
          }
        }
      }
    }

    return _NextWorkout(week: nextWeek, day: nextDay);
  }

  Future<_ProgressMetrics> _calculateProgress({
    required int programId,
    required Map<String, List<Map<String, dynamic>>> exercisesByDay,
    required Map<String, int> completedCountByDay,
    required Map<int, Set<int>> completedWorkoutsByWeek,
    required int currentWeek,
    required Set<String> workoutDates,
  }) async {
    final programData = await supabase
        .from('fitness_programs')
        .select('weeks')
        .eq('id', programId)
        .maybeSingle();

    final totalWeeks = programData?['weeks'] as int? ?? 6;

    final daysPerWeek =
        exercisesByDay.keys.where((k) => k.startsWith('1-')).length;
    final totalExpectedWorkoutSessions = totalWeeks * daysPerWeek;

    final Set<String> completedSessions = {};

    for (final weekEntry in completedWorkoutsByWeek.entries) {
      final week = weekEntry.key;
      for (final day in weekEntry.value) {
        completedSessions.add("$week-$day");
      }
    }

    int completedWorkoutSessions = completedSessions.length;

    for (int week = 2; week <= totalWeeks; week++) {
      for (int day = 1; day <= daysPerWeek; day++) {
        final key = '$week-$day';
        final completed = completedCountByDay[key] ?? 0;
        final isAlreadyCounted =
            completedWorkoutsByWeek[week]?.contains(day) ?? false;
        if (completed > 0 && !isAlreadyCounted) {
          final week1DayKey = '1-$day';
          final week1DayExercises = exercisesByDay[week1DayKey]?.length ?? 10;
          if (completed >= week1DayExercises) {
            completedWorkoutSessions++;
          }
        }
      }
    }

    final programProgress = totalExpectedWorkoutSessions > 0
        ? completedWorkoutSessions / totalExpectedWorkoutSessions
        : 0.0;

    developer.log(
        "Progress calculation: $completedWorkoutSessions/$totalExpectedWorkoutSessions sessions completed");
    developer.log(
        "  = ${(programProgress * 100).toInt()}% of $totalWeeks week program");

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final Map<int, bool> completedDays = {};
    for (int i = 1; i <= 7; i++) {
      final dayDate = startOfWeek.add(Duration(days: i - 1));
      final dateStr = dayDate.toIso8601String().substring(0, 10);
      if (workoutDates.contains(dateStr)) {
        completedDays[i] = true;
      }
    }

    final weekProgress = completedDays.length / 7.0;

    return _ProgressMetrics(
      currentWeek: currentWeek,
      completedDays: completedDays,
      programProgress: programProgress,
      weekProgress: weekProgress,
    );
  }

  Future<List<Map<String, dynamic>>> fetchWeek1Exercises({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    final exercisesData = await supabase
        .from('program_exercises')
        .select('''
          *,
          exercises (
            id,
            name,
            media_url,
            coaching_cues,
            exercise_category_association!exercise_category_association_exercise_id_fkey(
              category_id,
              exercise_categories!exercise_category_association_category_id_fkey(id, name)
            )
          )
        ''')
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber)
        .order('id');

    final exercises = <Map<String, dynamic>>[];

    for (final programEx in exercisesData as List) {
      final exerciseData = programEx['exercises'] as Map<String, dynamic>?;
      if (exerciseData == null) continue;

      final exerciseId = programEx['exercise_id'] as int;

      developer.log("Processing exercise ID: $exerciseId");

      final detailsData = await supabase
          .from('program_exercise_details')
          .select()
          .eq('program_exercise_id', programEx['id'])
          .maybeSingle();

      final categoryAssociations =
          exerciseData['exercise_category_association'] as List?;
      int? categoryId;
      String? categoryName;

      if (categoryAssociations != null && categoryAssociations.isNotEmpty) {
        final catData = categoryAssociations.first['exercise_categories'];
        categoryId = catData?['id'] as int?;
        categoryName = (catData?['name'] as String?)?.toLowerCase();
        developer.log(
            "  Exercise $exerciseId -> category_id: $categoryId, name: $categoryName");
      } else {
        developer.log("  Exercise $exerciseId has NO category association!");
      }

      final sets = detailsData?['sets'] as int? ?? 1;
      final minQuantity = detailsData?['min_quantity'] as int? ?? 0;

      // FIX: week 1 exercises also need set_quantities so the runner
      // can show the correct prescribed reps per set from day one.
      // For week 1 all sets are the same value (min_quantity).
      final setQuantities = List.filled(sets, minQuantity);

      exercises.add({
        'id': exerciseId,
        'program_exercise_id': programEx['id'],
        'name': exerciseData['name'],
        'media_url': exerciseData['media_url'],
        'coaching_cues': exerciseData['coaching_cues'],
        'sets': sets,
        'set_quantities': setQuantities, // FIX: add per-set quantities
        'min_quantity': minQuantity,
        'max_quantity': detailsData?['max_quantity'] ?? minQuantity,
        'duration_type': detailsData?['duration_type'] ?? 'reps',
        'is_superset': detailsData?['is_superset'] ?? false,
        'has_alternative': detailsData?['has_alternative'] ?? false,
        'alternative_exercise_id': detailsData?['alternative_exercise_id'],
        'alternative_set': detailsData?['alternative_sets'],
        'min_alternative': detailsData?['min_alternative'],
        'max_alternative': detailsData?['max_alternative'],
        'alternative_duration_type': detailsData?['alternative_duration_type'],
        'category_id': categoryId,
        'category_name': categoryName,
      });
    }

    int warmups = exercises.where((e) => e['category_name'] == 'warm-up').length;
    int mains = exercises.where((e) => e['category_name'] == 'main').length;
    int cooldowns =
        exercises.where((e) => e['category_name'] == 'cool-down').length;

    developer.log("\n=== CATEGORY SUMMARY ===");
    developer.log("Warmups: $warmups, Main: $mains, Cooldowns: $cooldowns");

    return exercises;
  }
}

class _ProgressData {
  final int currentWeek;
  final int? nextWeek;
  final int? nextDay;
  final Map<int, bool> completedDays;
  final Set<String> completedWorkoutDates;
  final double programProgress;
  final double weekProgress;

  _ProgressData({
    this.currentWeek = 1,
    this.nextWeek,
    this.nextDay,
    this.completedDays = const {},
    this.completedWorkoutDates = const {},
    this.programProgress = 0.0,
    this.weekProgress = 0.0,
  });
}

class _CompletionData {
  final Map<String, int> countByDay;
  final Map<String, DateTime> firstCompletionByDay;
  final Set<String> workoutDates;
  final Map<int, Set<int>> completedByWeek;

  _CompletionData({
    required this.countByDay,
    required this.firstCompletionByDay,
    required this.workoutDates,
    required this.completedByWeek,
  });
}

class _NextWorkout {
  final int? week;
  final int? day;
  _NextWorkout({this.week, this.day});
}

class _ProgressMetrics {
  final int currentWeek;
  final Map<int, bool> completedDays;
  final double programProgress;
  final double weekProgress;

  _ProgressMetrics({
    required this.currentWeek,
    required this.completedDays,
    required this.programProgress,
    required this.weekProgress,
  });
}