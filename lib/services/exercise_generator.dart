import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseGenerator {
  final supabase = Supabase.instance.client;

  /// Generates exercises for Week 2+ by applying progressive overload
  /// to Week 1 exercises based on the user's previous week performance
  Future<List<Map<String, dynamic>>> generateProgressiveExercises({
    required int programId,
    required int targetWeek,
    required int targetDay,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    print("Generating Week $targetWeek Day $targetDay from Week 1 Day $targetDay");

    // 1️⃣ Get the Week 1 exercises for this day number with full exercise details
    final week1Data = await supabase
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
        .eq('week_number', 1)
        .eq('day_number', targetDay)
        .order('id');

    if ((week1Data as List).isEmpty) {
      print("No Week 1 exercises found for day $targetDay");
      throw Exception('No template exercises found for day $targetDay');
    }

    // 2️⃣ Get the user's performance from the previous week
    final previousWeek = targetWeek - 1;
    final previousWeekLogs = await supabase
        .from('progress_logs')
        .select('exercise_id, reps_completed, weight_used_kg')
        .eq('user_id', user.id)
        .eq('program_id', programId)
        .eq('week_number', previousWeek)
        .eq('day_number', targetDay);

    // Create a map of exercise_id -> best performance in previous week
    final previousPerformance = _analyzePreviousPerformance(previousWeekLogs as List);

    print("Previous week performance: ${previousPerformance.keys.length} exercises tracked");

    // 3️⃣ Generate new exercises with progressive overload (+1 rep)
    final generatedExercises = <Map<String, dynamic>>[];

    for (final programEx in week1Data) {
      final exerciseId = programEx['exercise_id'] as int;
      final exerciseData = programEx['exercises'];

      // Get base values from Week 1
      final baseRepsMin = programEx['reps_min'] as int?;
      final baseRepsMax = programEx['reps_max'] as int?;
      final sets = programEx['sets'] as int? ?? 1;

      // Apply progressive overload
      final performance = previousPerformance[exerciseId];
      final newReps = _calculateProgressiveOverload(
        previousReps: performance?['reps'],
        baseMin: baseRepsMin,
        baseMax: baseRepsMax,
        exerciseId: exerciseId,
      );

      // Create the exercise in the format ExercisePreviewScreen expects
      final modifiedExercise = {
        'id': programEx['id'],
        'program_id': programId,
        'exercise_id': exerciseId,
        'week_number': targetWeek,
        'day_number': targetDay,
        'sets': sets,
        'reps_min': newReps['min']!,
        'reps_max': newReps['max']!,
        // Map to the fields ExercisePreviewScreen is looking for
        'min_quantity': newReps['min']!,
        'max_quantity': newReps['max']!,
        // Include exercise details
        'name': exerciseData?['name'] ?? 'Exercise',
        'media_url': exerciseData?['media_url'],
        'duration_type': 'reps', // Default to reps
      };

      generatedExercises.add(modifiedExercise);
    }

    print("Generated ${generatedExercises.length} exercises for Week $targetWeek Day $targetDay");
    return generatedExercises;
  }

  /// Analyzes previous week's performance to find the best result for each exercise
  Map<int, Map<String, dynamic>> _analyzePreviousPerformance(List logs) {
    final Map<int, Map<String, dynamic>> performance = {};

    for (final log in logs) {
      final exerciseId = log['exercise_id'] as int;
      final reps = log['reps_completed'] as int;
      final weight = log['weight_used_kg'] as double?;

      // Store the max reps completed for each exercise
      if (!performance.containsKey(exerciseId) ||
          reps > (performance[exerciseId]!['reps'] as int)) {
        performance[exerciseId] = {
          'reps': reps,
          'weight': weight,
        };
      }
    }

    return performance;
  }

  /// Calculates new rep targets with progressive overload
  Map<String, int> _calculateProgressiveOverload({
    required int? previousReps,
    required int? baseMin,
    required int? baseMax,
    required int exerciseId,
  }) {
    int newMin;
    int newMax;

    if (previousReps != null) {
      // User has done this exercise before - add 1 rep
      newMin = previousReps + 1;
      newMax = previousReps + 1;
      print("  Exercise $exerciseId: User did $previousReps reps, new target: $newMin");
    } else if (baseMin != null && baseMax != null) {
      // User hasn't done this exercise yet, use the base range from Week 1
      newMin = baseMin;
      newMax = baseMax;
      print("  Exercise $exerciseId: No previous data, using base range $newMin-$newMax");
    } else {
      // Fallback
      newMin = 10;
      newMax = 15;
      print("  Exercise $exerciseId: No data available, using default 10-15");
    }

    return {'min': newMin, 'max': newMax};
  }
}
