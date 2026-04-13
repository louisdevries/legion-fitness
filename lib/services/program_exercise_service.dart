import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'exercise_detail_service.dart';

final supabase = Supabase.instance.client;

class ProgramExerciseService {
  static Future<void> debugCategoryJoin(int exerciseId) async {
    debugPrint('=== DEBUG CATEGORY JOIN ===');

    try {
      final exercise = await supabase
          .from('exercises')
          .select('id, name')
          .eq('id', exerciseId)
          .maybeSingle();
      debugPrint('Step 1 - Exercise: $exercise');
    } catch (e) {
      debugPrint('Step 1 ERROR fetching exercise: $e');
    }

    try {
      final assoc = await supabase
          .from('exercise_category_association')
          .select('exercise_id, category_id')
          .eq('exercise_id', exerciseId);
      debugPrint('Step 2 - Associations: $assoc');
    } catch (e) {
      debugPrint('Step 2 ERROR fetching associations: $e');
    }

    try {
      final cats = await supabase
          .from('exercise_categories')
          .select('id, name');
      debugPrint('Step 3 - Categories: $cats');
    } catch (e) {
      debugPrint('Step 3 ERROR fetching categories: $e');
    }

    try {
      final noHint = await supabase
          .from('exercises')
          .select('id, name, exercise_category_association(category_id)')
          .eq('id', exerciseId)
          .maybeSingle();
      debugPrint('Step 4 - Join without hint: $noHint');
    } catch (e) {
      debugPrint('Step 4 ERROR join without hint: $e');
    }

    try {
      final oneHint = await supabase
          .from('exercises')
          .select(
          'id, name, exercise_category_association!exercise_category_association_exercise_id_fkey(category_id)')
          .eq('id', exerciseId)
          .maybeSingle();
      debugPrint('Step 5 - Join with one hint: $oneHint');
    } catch (e) {
      debugPrint('Step 5 ERROR join with one hint: $e');
    }

    try {
      final fullHint = await supabase
          .from('exercises')
          .select('''
            id, name,
            exercise_category_association!exercise_category_association_exercise_id_fkey(
              category_id,
              exercise_categories!exercise_category_association_category_id_fkey(id, name)
            )
          ''')
          .eq('id', exerciseId)
          .maybeSingle();
      debugPrint('Step 6 - Join with full hints: $fullHint');
    } catch (e) {
      debugPrint('Step 6 ERROR join with full hints: $e');
    }

    debugPrint('=== END DEBUG ===');
  }

  static Future<List<Map<String, dynamic>>> fetchExercisesForDay({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final data = await supabase
        .from('program_exercises')
        .select()
        .eq('program_id', programId)
        .eq('week_number', 1)
        .eq('day_number', dayNumber);

    final programExercises = List<Map<String, dynamic>>.from(data);
    final List<Map<String, dynamic>> exercisesWithDetails = [];

    // Debug the first exercise to check join
    if (programExercises.isNotEmpty) {
      await debugCategoryJoin(programExercises.first['exercise_id'] as int);
    }

    for (final pe in programExercises) {
      final exerciseInfo = await supabase
          .from('exercises')
          .select('''
            *,
            exercise_category_association!exercise_category_association_exercise_id_fkey(
              category_id,
              exercise_categories!exercise_category_association_category_id_fkey(id, name)
            )
          ''')
          .eq('id', pe['exercise_id'])
          .maybeSingle();

      if (exerciseInfo == null) continue;

      final categoryAssociations =
      exerciseInfo['exercise_category_association'] as List?;
      int? categoryId;
      String? categoryName;

      if (categoryAssociations != null && categoryAssociations.isNotEmpty) {
        final catData = categoryAssociations.first['exercise_categories'];
        categoryId = catData?['id'] as int?;
        categoryName = (catData?['name'] as String?)?.toLowerCase();
      }

      final details =
      await ProgramExerciseDetailService.fetchDetailsForExercise(pe['id']);
      final detail = details.isNotEmpty ? details.first : null;

      int minQ = detail?.minQuantity ?? 0;
      int maxQ = detail?.maxQuantity ?? minQ;

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

          if (bestReps >= maxQ) {
            minQ += 1;
            maxQ += 1;
          }
        }
      }

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
        'category_id': categoryId,
        'category_name': categoryName,
      };

      exercisesWithDetails.add(merged);
    }

    return exercisesWithDetails;
  }
}