import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';

final supabase = Supabase.instance.client;

class ExerciseService {
  /// Fetch all exercises (ignoring program/week/day for now)
  static Future<List<Exercise>> getAllExercises() async {
    final data = await supabase.from('exercises').select();
    return (data as List)
        .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Optional: fetch exercises for a specific day
  static Future<List<Exercise>> fetchExercisesForDay({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    // 1️⃣ Get exercise IDs for this program/week/day
    final data = await supabase
        .from('program_exercises')
        .select('exercise_id')
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber);

    final exerciseIds = (data as List).map((e) => e['exercise_id'] as int).toList();

    if (exerciseIds.isEmpty) return [];

    // 2️⃣ Fetch exercise details
    final exercisesData = await supabase
        .from('exercises')
        .select()
        .filter('id', 'in', exerciseIds);

    return (exercisesData as List)
        .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
