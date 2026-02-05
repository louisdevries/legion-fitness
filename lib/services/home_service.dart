import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_state.dart';

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
        print("No user logged in");
        return _ProgressData();
      }

      // 1️⃣ Fetch all exercises in the program
      final allExercisesData = await supabase
          .from('program_exercises')
          .select('id, week_number, day_number')
          .eq('program_id', programId)
          .order('week_number', ascending: true)
          .order('day_number', ascending: true);

      if (allExercisesData == null || (allExercisesData as List).isEmpty) {
        print("No exercises found for program $programId");
        return _ProgressData();
      }

      final allExercises = (allExercisesData as List)
          .map((e) => {
        'id': e['id'],
        'week': (e['week_number'] as num).toInt(),
        'day': (e['day_number'] as num).toInt(),
      })
          .toList();

      print("Total exercises in program: ${allExercises.length}");

      // Debug: Show distribution of exercises
      final exerciseDistribution = _getExerciseDistribution(allExercises);
      print("Exercise distribution by week/day: $exerciseDistribution");

      // 2️⃣ Group exercises by week-day combination
      final exercisesByDay = _groupExercisesByDay(allExercises);
      print("Exercise groups: ${exercisesByDay.keys.toList()}");

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

      print("=== RAW DATA DEBUG ===");
      print("Total logs fetched: ${completedLogsData.length}");
      print("Completed count by day: ${completionData.countByDay}");
      print("First completions: ${completionData.firstCompletionByDay}");
      print("Unique workout dates: ${completionData.workoutDates}");

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

      print("=== PROGRESS DEBUG ===");
      print("Next workout -> Week: ${nextWorkout.week}, Day: ${nextWorkout.day}");
      print("Current week (program): ${progressMetrics.currentWeek}");
      print("This calendar week completed days: ${progressMetrics.completedDays}");
      print("Program progress: ${(progressMetrics.programProgress * 100).toInt()}%");

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
      print("ERROR in _loadProgress: $e");
      print(stack);
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
        print("Warning: Log missing week or day number: $log");
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
        print("Error parsing date for log: $e");
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

    print("Completed workouts by week: $completedByWeek");

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

    print("Checking workout days in order: $sortedKeys");

    // First, check if any Week 1 workouts are incomplete
    for (final key in sortedKeys) {
      final exercises = exercisesByDay[key]!;
      final completed = completedCountByDay[key] ?? 0;
      final isComplete = completed >= exercises.length;

      print("  $key: ${exercises.length} exercises, $completed completed, complete=$isComplete");

      if (!isComplete) {
        final parts = key.split('-');
        nextWeek = int.parse(parts[0]);
        nextDay = int.parse(parts[1]);
        print("  -> Found incomplete Week 1 workout: Week $nextWeek, Day $nextDay");
        break;
      }
    }

    // If Week 1 is complete, determine the next week/day based on program structure
    if (nextWeek == null) {
      print("Week 1 is complete. Checking for next week...");

      // Get the program info to know total weeks
      final programData = await supabase
          .from('fitness_programs')
          .select('weeks')
          .eq('id', programId)
          .maybeSingle();

      final totalWeeks = programData?['weeks'] as int? ?? 6;
      print("Program has $totalWeeks total weeks");

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

      print("Highest week with any completion: $highestCompletedWeek");

      // Check which days are complete in the highest week
      final daysPerWeek = exercisesByDay.keys.where((k) => k.startsWith('1-')).length;
      print("Days per week: $daysPerWeek");

      // Check if the highest week is fully complete
      int completedDaysInHighestWeek = 0;
      for (int day = 1; day <= daysPerWeek; day++) {
        final key = '$highestCompletedWeek-$day';
        final completed = completedCountByDay[key] ?? 0;
        if (completed > 0) {
          completedDaysInHighestWeek++;
        }
      }

      print("Completed days in week $highestCompletedWeek: $completedDaysInHighestWeek/$daysPerWeek");

      if (completedDaysInHighestWeek >= daysPerWeek) {
        // Current week is complete, move to next week
        if (highestCompletedWeek < totalWeeks) {
          nextWeek = highestCompletedWeek + 1;
          nextDay = 1;
          print("  -> Moving to next week: Week $nextWeek, Day $nextDay");
        } else {
          print("  -> Program completed!");
        }
      } else {
        // Find next incomplete day in current week
        for (int day = 1; day <= daysPerWeek; day++) {
          final key = '$highestCompletedWeek-$day';
          final completed = completedCountByDay[key] ?? 0;
          if (completed == 0) {
            nextWeek = highestCompletedWeek;
            nextDay = day;
            print("  -> Found incomplete day in week $highestCompletedWeek: Day $nextDay");
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

    print("Progress calculation: $completedWorkoutSessions/$totalExpectedWorkoutSessions sessions completed");
    print("  = ${(programProgress * 100).toInt()}% of $totalWeeks week program");

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
            media_url
          )
        ''')
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber)
        .order('id');

    // Map to the format ExercisePreviewScreen expects
    return (exercisesData as List).map((programEx) {
      final exerciseData = programEx['exercises'];
      return {
        'id': programEx['id'],
        'program_id': programEx['program_id'],
        'exercise_id': programEx['exercise_id'],
        'week_number': programEx['week_number'],
        'day_number': programEx['day_number'],
        'sets': programEx['sets'] ?? 1,
        'reps_min': programEx['reps_min'],
        'reps_max': programEx['reps_max'],
        // Map to the fields ExercisePreviewScreen is looking for
        'min_quantity': programEx['reps_min'],
        'max_quantity': programEx['reps_max'],
        // Include exercise details
        'name': exerciseData?['name'] ?? 'Exercise',
        'media_url': exerciseData?['media_url'],
        'duration_type': 'reps', // Default to reps
      };
    }).toList();
  }
}

// Helper classes for internal use
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
    Map<int, bool>? completedDays,
    Set<String>? completedWorkoutDates,
    this.programProgress = 0.0,
    this.weekProgress = 0.0,
  })  : completedDays = completedDays ?? {},
        completedWorkoutDates = completedWorkoutDates ?? {};
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
