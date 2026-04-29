import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseGenerator {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> generateProgressiveExercises({
    required int programId,
    required int targetWeek,
    required int targetDay,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    print("Generating Week $targetWeek Day $targetDay from Week 1 Day $targetDay");

    final week1Data = await supabase
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
        .eq('week_number', 1)
        .eq('day_number', targetDay)
        .order('id');

    if ((week1Data as List).isEmpty) {
      throw Exception('No template exercises found for day $targetDay');
    }

    final previousWeek = targetWeek - 1;
    final previousWeekLogs = await supabase
        .from('exercise_completions')
        .select('exercise_id, reps_completed, set_index')
        .eq('user_id', user.id)
        .eq('program_id', programId)
        .eq('week_number', previousWeek)
        .eq('day_number', targetDay)
        .order('exercise_id')
        .order('set_index'); // ensures sets come back in order

    // FIX: keeps all sets in order, not just the max
    final previousPerformance =
    _analyzePreviousPerformance(previousWeekLogs as List);

    print("Previous week performance: ${previousPerformance.keys.length} exercises tracked");

    final generatedExercises = <Map<String, dynamic>>[];

    for (final programEx in week1Data) {
      final exerciseId = programEx['exercise_id'] as int;
      final exerciseData = programEx['exercises'];

      final detailsData = await supabase
          .from('program_exercise_details')
          .select()
          .eq('program_exercise_id', programEx['id'])
          .maybeSingle();

      final baseRepsMin = detailsData?['min_quantity'] as int? ?? 10;
      final sets = detailsData?['sets'] as int? ?? 1;

      final categoryResult = await supabase
          .from('exercise_category_association')
          .select('category_id')
          .eq('exercise_id', exerciseId)
          .maybeSingle();

      String category = 'main';
      if (categoryResult != null) {
        final categoryId = categoryResult['category_id'] as int?;
        if (categoryId == 1) {
          category = 'warmup';
        } else if (categoryId == 3) {
          category = 'cooldown';
        } else {
          category = 'main';
        }
      }

      final alternativeData = await supabase
          .from('exercise_alternatives')
          .select('''
            alternative_id,
            exercises!exercise_alternatives_alternative_id_fkey(
              id,
              name,
              media_url,
              coaching_cues
            )
          ''')
          .eq('exercise_id', exerciseId)
          .maybeSingle();

      Map<String, dynamic>? alternative;
      if (alternativeData != null && alternativeData['exercises'] != null) {
        final altEx = alternativeData['exercises'];
        alternative = {
          'id': altEx['id'],
          'name': altEx['name'],
          'media_url': altEx['media_url'],
          'coaching_cues': altEx['coaching_cues'] ?? '',
          'sets': sets,
          'min_quantity': baseRepsMin,
          'max_quantity': baseRepsMin,
          'duration_type': detailsData?['duration_type'] ?? 'reps',
        };
      }

      // FIX: per-set quantities, each incremented by 1 from previous week
      final List<int> previousSets = previousPerformance[exerciseId] ?? [];

      final List<int> setQuantities;
      if (previousSets.isNotEmpty) {
        // Increment each set's actual logged reps by 1 independently
        setQuantities = previousSets.map((r) => r + 1).toList();
        print("  Exercise $exerciseId: previous sets $previousSets -> $setQuantities");
      } else {
        // No history — use week 1 base value repeated for each set
        setQuantities = List.filled(sets, baseRepsMin);
        print("  Exercise $exerciseId: no history, using base $baseRepsMin x$sets sets");
      }

      generatedExercises.add({
        'id': programEx['id'],
        'program_id': programId,
        'exercise_id': exerciseId,
        'week_number': targetWeek,
        'day_number': targetDay,
        'sets': setQuantities.length,
        'set_quantities': setQuantities,       // per-set rep targets
        'min_quantity': setQuantities.first,   // for display fallback
        'max_quantity': setQuantities.first,
        'name': exerciseData?['name'] ?? 'Exercise',
        'media_url': exerciseData?['media_url'],
        'coaching_cues': exerciseData?['coaching_cues'] ?? '',
        'duration_type': detailsData?['duration_type'] ?? 'reps',
        'category': category,
        'alternative': alternative,
      });
    }

    generatedExercises.sort((a, b) {
      final order = {'warmup': 0, 'main': 1, 'cooldown': 2};
      final aOrder = order[a['category']] ?? 1;
      final bOrder = order[b['category']] ?? 1;
      return aOrder.compareTo(bOrder);
    });

    print("Generated ${generatedExercises.length} exercises for Week $targetWeek Day $targetDay");
    return generatedExercises;
  }

  // FIX: returns ordered list of reps per set, not just the max
  Map<int, List<int>> _analyzePreviousPerformance(List logs) {
    final Map<int, List<int>> performance = {};

    for (final log in logs) {
      final exerciseId = log['exercise_id'] as int?;
      final reps = log['reps_completed'] as int? ?? 0;
      if (exerciseId == null) continue;
      performance.putIfAbsent(exerciseId, () => []).add(reps);
    }

    return performance;
  }
}