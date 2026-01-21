import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program_exercise_details.dart';
import 'exercise_detail_service.dart';

final supabase = Supabase.instance.client;

class ProgramExerciseService {
  /// Fetch all exercises for a program + week + day
  static Future<List<Map<String, dynamic>>> fetchExercisesForDay({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    final data = await supabase
        .from('program_exercises')
        .select()
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber);

    final programExercises = List<Map<String, dynamic>>.from(data);

    final List<Map<String, dynamic>> exercisesWithDetails = [];

    for (final pe in programExercises) {
      // 1️⃣ Exercise info
      final exerciseInfo = await supabase
          .from('exercises')
          .select()
          .eq('id', pe['exercise_id'])
          .maybeSingle();

      if (exerciseInfo == null) continue;

      // 2️⃣ Program exercise details
      final details = await ProgramExerciseDetailService.fetchDetailsForExercise(pe['id']);
      final detail = details.isNotEmpty ? details[0] : null;

      final merged = {
        ...exerciseInfo,
        'program_exercise_id': pe['id'],
        'sets': detail?.sets ?? 1,
        'min_quantity': detail?.minQuantity ?? 0,
        'max_quantity': detail?.maxQuantity ?? detail?.minQuantity ?? 0,
        'duration_type': detail?.durationType ?? 'reps',
        'is_superset': detail?.isSuperset ?? false,
        'has_alternative': detail?.hasAlternative ?? false,
        'alternative_exercise_id': detail?.alternativeExerciseId,
        'alternative_set': detail?.alternativeSet,
        'min_alternative': detail?.minAlternative,
        'max_alternative': detail?.maxAlternative,
        'alternative_duration_type': detail?.alternativeDurationType,
      };

      exercisesWithDetails.add(merged);
    }

    return exercisesWithDetails;
  }
}
