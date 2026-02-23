import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_state.dart';
import 'dart:developer' as developer;

class HomeService {
  final supabase = Supabase.instance.client;

  /// Loads all home screen data including program info and progress
  Future<HomeState> loadHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    final programId = prefs.getInt('active_program_id');

    if (programId == null) {
      return HomeState(isLoading: false);
    }

    final programInfo = await _loadProgramInfo(programId);
    final progressData = await _loadProgress(programId);

    // Save the current week to prefs
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

  /// Loads basic program information
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

  /// Loads and calculates all progress data
  Future<_ProgressData> _loadProgress(int programId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        developer.log("No user logged in");
        return _ProgressData();
      }

      // 1️⃣ Fetch all exercises in the program
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

      // Debug: Show distribution of exercises
      final exerciseDistribution = _getExerciseDistribution(allExercises);
      developer.log("Exercise distribution by week/day: $exerciseDistribution");

      // 2️⃣ Group exercises by week-day combination
      final exercisesByDay = _groupExercisesByDay(allExercises);
      developer.log("Exercise groups: ${exercisesByDay.keys.toList()}");

      // 3️⃣ Fetch ALL completed logs with timestamps
      final completedLogsData = await supabase
          .from('progress_logs')
          .select('week_number, day_number, exercise_id, date')
          .eq('user_id', user.id)
          .eq('program_id', programId);

      // Count completed exercises per workout day
      final completionData = _analyzeCompletionData(
        completedLogsData as List,
        exercisesByDay,
      );

      developer.log("=== RAW DATA DEBUG ===");
      developer.log("Total logs fetched: ${completedLogsData.length}");
      developer.log("Completed count by day: ${completionData.countByDay}");
      developer.log("First completions: ${completionData.firstCompletionByDay}");
      developer.log("Unique workout dates: ${completionData.workoutDates}");

      // 4️⃣ Find the next incomplete workout
      final nextWorkout = await _findNextWorkout(
        exercisesByDay: exercisesByDay,
        completedCountByDay: completionData.countByDay,
        programId: programId,
      );

      // 5️⃣ Calculate progress metrics
      final progressMetrics = await _calculateProgress(
        programId: programId,
        exercisesByDay: exercisesByDay,
        completedCountByDay: completionData.countByDay,
        completedWorkoutsByWeek: completionData.completedByWeek,
        currentWeek: nextWorkout.week ?? 1,
        workoutDates: completionData.workoutDates,
      );

      developer.log("=== PROGRESS DEBUG ===");
      developer.log("Next workout -> Week: ${nextWorkout.week}, Day: ${nextWorkout.day}");
      developer.log("Current week (program): ${progressMetrics.currentWeek}");
      developer.log("This calendar week completed days: ${progressMetrics.completedDays}");
      developer.log("Program progress: ${(progressMetrics.programProgress * 100).toInt()}%");

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

  /// Groups exercises by week-day key
  Map<String, List<Map<String, dynamic>>> _groupExercisesByDay(
      List<Map<String, dynamic>> exercises) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final e in exercises) {
      final key = "${e['week']}-${e['day']}";
      grouped.putIfAbsent(key, () => []).add(e);
    }
    return grouped;
  }

  /// Gets distribution of exercises across weeks and days
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

  /// Analyzes completion data from progress logs
  _CompletionData _analyzeCompletionData(
      List logs,
      Map<String, List<Map<String, dynamic>>> exercisesByDay,
      ) {
    final Map<String, int> countByDay = {};
    final Map<String, DateTime> firstCompletionByDay = {};
    final Set<String> workoutDates = {};

    for (final log in logs) {
      final weekNum = (log['week_number'] as num?)?.toInt();
      final dayNum = (log['day_number'] as num?)?.toInt();

      if (weekNum == null || dayNum == null) {
        developer.log("Warning: Log missing week or day number: $log");
        continue;
      }

      final key = "$weekNum-$dayNum";
      countByDay[key] = (countByDay[key] ?? 0) + 1;

      // Track the actual calendar date when workout was done
      try {
        if (log['date'] != null) {
          final date = DateTime.parse(log['date']);
          // Store the first completion time for this workout day
          if (!firstCompletionByDay.containsKey(key)) {
            firstCompletionByDay[key] = date;
          }
          final dateStr = date.toIso8601String().substring(0, 10);
          workoutDates.add(dateStr);
        }
      } catch (e) {
        developer.log("Error parsing date for log: $e");
      }
    }

    // Determine which workout days are fully completed
    final Map<int, Set<int>> completedByWeek = {};
    countByDay.forEach((key, count) {
      final exercises = exercisesByDay[key];
      final exerciseCount = exercises?.length ?? 0;
      if (exerciseCount > 0 && count >= exerciseCount) {
        final parts = key.split('-');
        final week = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        completedByWeek.putIfAbsent(week, () => {}).add(day);
      }
    });

    developer.log("Completed workouts by week: $completedByWeek");

    return _CompletionData(
      countByDay: countByDay,
      firstCompletionByDay: firstCompletionByDay,
      workoutDates: workoutDates,
      completedByWeek: completedByWeek,
    );
  }

  /// Finds the next incomplete workout
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

    // First, check if any Week 1 workouts are incomplete
    for (final key in sortedKeys) {
      final exercises = exercisesByDay[key]!;
      final completed = completedCountByDay[key] ?? 0;
      final isComplete = completed >= exercises.length;

      developer.log("  $key: ${exercises.length} exercises, $completed completed, complete=$isComplete");

      if (!isComplete) {
        final parts = key.split('-');
        nextWeek = int.parse(parts[0]);
        nextDay = int.parse(parts[1]);
        developer.log("  -> Found incomplete Week 1 workout: Week $nextWeek, Day $nextDay");
        break;
      }
    }

    // If Week 1 is complete, determine the next week/day based on program structure
    if (nextWeek == null) {
      developer.log("Week 1 is complete. Checking for next week...");

      // Get the program info to know total weeks
      final programData = await supabase
          .from('fitness_programs')
          .select('weeks')
          .eq('id', programId)
          .maybeSingle();

      final totalWeeks = programData?['weeks'] as int? ?? 6;
      developer.log("Program has $totalWeeks total weeks");

      // Find the highest week in completed logs
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

      // Check which days are complete in the highest week
      final daysPerWeek = exercisesByDay.keys.where((k) => k.startsWith('1-')).length;
      developer.log("Days per week: $daysPerWeek");

      // Check if the highest week is fully complete
      int completedDaysInHighestWeek = 0;
      for (int day = 1; day <= daysPerWeek; day++) {
        final key = '$highestCompletedWeek-$day';
        final completed = completedCountByDay[key] ?? 0;
        if (completed > 0) {
          completedDaysInHighestWeek++;
        }
      }

      developer.log("Completed days in week $highestCompletedWeek: $completedDaysInHighestWeek/$daysPerWeek");

      if (completedDaysInHighestWeek >= daysPerWeek) {
        // Current week is complete, move to next week
        if (highestCompletedWeek < totalWeeks) {
          nextWeek = highestCompletedWeek + 1;
          nextDay = 1;
          developer.log("  -> Moving to next week: Week $nextWeek, Day $nextDay");
        } else {
          developer.log("  -> Program completed!");
        }
      } else {
        // Find next incomplete day in current week
        for (int day = 1; day <= daysPerWeek; day++) {
          final key = '$highestCompletedWeek-$day';
          final completed = completedCountByDay[key] ?? 0;
          if (completed == 0) {
            nextWeek = highestCompletedWeek;
            nextDay = day;
            developer.log("  -> Found incomplete day in week $highestCompletedWeek: Day $nextDay");
            break;
          }
        }
      }
    }

    return _NextWorkout(week: nextWeek, day: nextDay);
  }

  /// Calculates all progress metrics
  Future<_ProgressMetrics> _calculateProgress({
    required int programId,
    required Map<String, List<Map<String, dynamic>>> exercisesByDay,
    required Map<String, int> completedCountByDay,
    required Map<int, Set<int>> completedWorkoutsByWeek,
    required int currentWeek,
    required Set<String> workoutDates,
  }) async {
    // Get total weeks from program
    final programData = await supabase
        .from('fitness_programs')
        .select('weeks')
        .eq('id', programId)
        .maybeSingle();

    final totalWeeks = programData?['weeks'] as int? ?? 6;

    // Calculate total expected exercises across all weeks
    final daysPerWeek = exercisesByDay.keys.where((k) => k.startsWith('1-')).length;
    final totalExpectedWorkoutSessions = totalWeeks * daysPerWeek;

    // Count completed sessions
    int completedWorkoutSessions = 0;
    for (final weekData in completedWorkoutsByWeek.entries) {
      completedWorkoutSessions += weekData.value.length;
    }

    // For weeks beyond Week 1, check progress logs
    for (int week = 2; week <= totalWeeks; week++) {
      for (int day = 1; day <= daysPerWeek; day++) {
        final key = '$week-$day';
        final completed = completedCountByDay[key] ?? 0;
        // Check if this day is not already counted in completedByWeek
        final isAlreadyCounted = completedWorkoutsByWeek[week]?.contains(day) ?? false;
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

    developer.log("Progress calculation: $completedWorkoutSessions/$totalExpectedWorkoutSessions sessions completed");
    developer.log("  = ${(programProgress * 100).toInt()}% of $totalWeeks week program");

    // Calculate THIS CALENDAR WEEK's progress (Mon-Sun)
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

  /// Fetches Week 1 exercises for the ExercisePreviewScreen
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
            coaching_cues
          )
        ''')
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber)
        .order('id');

    final exercises = <Map<String, dynamic>>[];

    for (final programEx in exercisesData as List) {
      final exerciseData = programEx['exercises'];
      final exerciseId = programEx['exercise_id'] as int;

      developer.log("Processing exercise ID: $exerciseId");

      // Fetch exercise details (sets, reps, duration)
      final detailsData = await supabase
          .from('program_exercise_details')
          .select()
          .eq('program_exercise_id', programEx['id'])
          .maybeSingle();

      // Determine category (Warmup, Main, Cooldown)
      final categoryData = await supabase
          .from('exercise_category_map')
          .select('category_id, exercise_categories(name)')
          .eq('exercise_id', exerciseId)
          .maybeSingle();

      String category = "Main Lift";
      if (categoryData != null) {
        category = categoryData['exercise_categories']['name'] as String;
        developer.log("  Exercise $exerciseId has category_id: ${categoryData['category_id']}");
      } else {
        developer.log("  Exercise $exerciseId has NO category association!");
      }

      developer.log("  Final category: $category");

      exercises.add({
        'id': exerciseId,
        'program_exercise_id': programEx['id'],
        'name': exerciseData['name'],
        'media_url': exerciseData['media_url'],
        'coaching_cues': exerciseData['coaching_cues'],
        'sets': detailsData?['sets'],
        'reps': detailsData?['reps'],
        'duration': detailsData?['duration_seconds'],
        'category': category,
      });
    }

    // Count categories for debug
    int warmups = exercises.where((e) => e['category'] == 'Warmup').length;
    int mains = exercises.where((e) => e['category'] == 'Main Lift').length;
    int cooldowns = exercises.where((e) => e['category'] == 'Cooldown').length;

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
