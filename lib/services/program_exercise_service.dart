import 'package:supabase_flutter/supabase_flutter.dart';
import 'exercise_detail_service.dart';

final supabase = Supabase.instance.client;

class ProgramExerciseService {
  static Future<List<Map<String, dynamic>>> fetchExercisesForDay({
    required int programId,
    required int weekNumber, // still used for progression + logging
    required int dayNumber,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    // ✅ ALWAYS fetch exercises from WEEK 1 TEMPLATE
    final data = await supabase
        .from('program_exercises')
        .select()
        .eq('program_id', programId)
        .eq('week_number', 1) // 🔑 FIX: week 1 only
        .eq('day_number', dayNumber);

    final programExercises = List<Map<String, dynamic>>.from(data);
    final List<Map<String, dynamic>> exercisesWithDetails = [];

    for (final pe in programExercises) {
      // 2️⃣ Exercise info
      final exerciseInfo = await supabase
          .from('exercises')
          .select()
          .eq('id', pe['exercise_id'])
          .maybeSingle();

      if (exerciseInfo == null) continue;

      // 3️⃣ Program exercise details (BASE values)
      final details =
      await ProgramExerciseDetailService.fetchDetailsForExercise(pe['id']);
      final detail = details.isNotEmpty ? details.first : null;

      int minQ = detail?.minQuantity ?? 0;
      int maxQ = detail?.maxQuantity ?? minQ;

      // 4️⃣ Apply progression (based on PREVIOUS WEEK LOGS)
      if (weekNumber > 1) {
        final prevWeek = weekNumber - 1;

        final prevLogs = await supabase
            .from('progress_logs')
            .select('reps_completed')
            .eq('program_id', programId)
            .eq('exercise_id', pe['exercise_id'])
            .eq('week_number', prevWeek)
            .eq('day_number', dayNumber)
            .eq('user_id', userId);

        if (prevLogs.isNotEmpty) {
          final bestReps = prevLogs
              .map((e) => e['reps_completed'] as int)
              .reduce((a, b) => a > b ? a : b);

          // 📈 Simple progression rule
          if (bestReps >= maxQ) {
            minQ += 1;
            maxQ += 1;
          }
        }
      }

      // 5️⃣ Merge everything into runner-friendly structure
      final merged = {
        ...exerciseInfo,
        'program_exercise_id': pe['id'],
        'sets': detail?.sets ?? 1,
        'min_quantity': minQ,
        'max_quantity': maxQ,
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
