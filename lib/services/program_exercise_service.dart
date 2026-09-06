import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'exercise_detail_service.dart';
import '../utils/rep_scheme_utils.dart';

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

    debugPrint("🔍 fetchExercisesForDay called: program=$programId week=$weekNumber day=$dayNumber");
    final userId = supabase.auth.currentUser!.id;

    final data = await supabase
        .from('program_exercises')
        .select()
        .eq('program_id', programId)
        .eq('week_number', 1)
        .eq('day_number', dayNumber);

    final programExercises = List<Map<String, dynamic>>.from(data);
    final List<Map<String, dynamic>> exercisesWithDetails = [];

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
      int? associationCategoryId;
      String? associationCategoryName;

      if (categoryAssociations != null && categoryAssociations.isNotEmpty) {
        final catData = categoryAssociations.first['exercise_categories'];
        associationCategoryId = catData?['id'] as int?;
        associationCategoryName = (catData?['name'] as String?)?.toLowerCase();
      }

      // Prefer the per-slot category on program_exercises.category_id, so
      // the same exercise can be a warmup in one program and a main lift
      // in another. Falls back to the exercise's default association for
      // rows seeded before the category_id column existed, and to "main"
      // if neither is set. When the slot overrides the category, leave
      // categoryName null — downstream consumers already fall back to
      // the 1/warmup, 2/main, 3/cooldown category_id convention.
      final slotCategoryId = pe['category_id'] as int?;
      final categoryId = slotCategoryId ?? associationCategoryId ?? 2;
      final categoryName =
          slotCategoryId == null ? associationCategoryName : null;

      final details =
      await ProgramExerciseDetailService.fetchDetailsForExercise(pe['id']);
      final detail = details.isNotEmpty ? details.first : null;

      final sets = detail?.sets ?? 1;
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

      // ── Fetch alternative exercise data ───────────────────────────
      Map<String, dynamic>? alternativeExercise;
      final altExerciseId = detail?.alternativeExerciseId;

      if (altExerciseId != null) {
        debugPrint('Fetching alternative exercise for id=$altExerciseId');

        final altData = await supabase
            .from('exercises')
            .select('id, name, media_url, coaching_cues')
            .eq('id', altExerciseId)
            .maybeSingle();

        debugPrint('Alternative exercise data: $altData');

        if (altData != null) {
          final altSets = detail?.alternativeSet ?? sets;
          final altMinQ = detail?.minAlternative ?? minQ;
          final altMaxQ = detail?.maxAlternative ?? maxQ;
          alternativeExercise = {
            'id': altData['id'],
            'name': altData['name'] ?? 'Alternative Exercise',
            'media_url': altData['media_url'] ?? '',
            'coaching_cues': altData['coaching_cues'] ?? '',
            'sets': altSets,
            'min_quantity': altMinQ,
            'max_quantity': altMaxQ,
            'duration_type':
            detail?.alternativeDurationType ?? detail?.durationType ?? 'reps',
            'set_quantities': RepSchemeUtils.evenlySpaced(
                sets: altSets, minQuantity: altMinQ, maxQuantity: altMaxQ),
          };
        }
      }
      // ─────────────────────────────────────────────────────────────

      // Resolve per-set quantities — use the stored set_quantities array
      // if this row has one, otherwise spread min..max evenly across sets.
      final setQuantities = (detail?.setQuantities != null &&
              detail!.setQuantities!.isNotEmpty)
          ? detail.setQuantities!
          : RepSchemeUtils.evenlySpaced(
              sets: sets, minQuantity: minQ, maxQuantity: maxQ);

      final merged = {
        ...exerciseInfo,
        'program_exercise_id': pe['id'],
        'sets': sets,
        'min_quantity': minQ,
        'max_quantity': maxQ,
        'set_quantities': setQuantities,
        'duration_type': detail?.durationType ?? 'reps',
        'is_superset': detail?.isSuperset ?? false,
        'has_alternative': detail?.hasAlternative ?? false,
        'alternative_exercise_id': altExerciseId,
        'alternative_exercise': alternativeExercise, // ← now populated
        'alternative_set': detail?.alternativeSet,
        'min_alternative': detail?.minAlternative,
        'max_alternative': detail?.maxAlternative,
        'alternative_duration_type': detail?.alternativeDurationType,
        'category_id': categoryId,
        'category_name': categoryName,
        'tempo': detail?.tempo,
      };

      exercisesWithDetails.add(merged);
    }

    return exercisesWithDetails;
  }
}