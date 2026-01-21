import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';

final supabase = Supabase.instance.client;

Future<List<Exercise>> fetchExercisesForDay({
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

  // 2️⃣ Fetch exercise details using the correct .filter syntax
  final exercisesData = await supabase
      .from('exercises')
      .select()
      .filter('id', 'in', exerciseIds);

  final exercisesList = (exercisesData as List)
      .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
      .toList();

  return exercisesList;
}
