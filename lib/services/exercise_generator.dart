import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class ExerciseGenerator {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> generateProgressiveExercises({
    required int programId,
    required int targetWeek,
    required int targetDay,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    developer.log("Generating Week $targetWeek Day $targetDay");

    // Fetch week 1 template
    final week1Data = await supabase
        .from('program_exercises')
        .select('''
          *,
          exercises (
            id, name, media_url, coaching_cues,
            exercise_category_association!exercise_category_association_exercise_id_fkey(
              category_id,
              exercise_categories!exercise_category_association_category_id_fkey(id, name)
            )
          )
        ''')
        .eq('program_id', programId)
        .eq('week_number', 1)
        .eq('day_number', targetDay)
        .order('id');

    if ((week1Data as List).isEmpty) {
      throw Exception('No template exercises found for day $targetDay');
    }

    // Fetch previous week completions for main exercises
    final previousWeek = targetWeek - 1;
    final previousLogs = await supabase
        .from('exercise_completions')
        .select('exercise_id, reps_completed, set_index')
        .eq('user_id', user.id)
        .eq('program_id', programId)
        .eq('week_number', previousWeek)
        .eq('day_number', targetDay)
        .order('exercise_id')
        .order('set_index');

    // Map: exerciseId -> { setIndex -> repsCompleted }
    final previousPerformance =
    _analyzePerformanceBySet(previousLogs as List);

    developer.log(
        "Previous week performance: ${previousPerformance.keys.length} exercises");

    final generatedExercises = <Map<String, dynamic>>[];

    for (final programEx in week1Data) {
      final exerciseData = programEx['exercises'] as Map<String, dynamic>?;
      if (exerciseData == null) continue;

      final exerciseId = programEx['exercise_id'] as int;

      // Fetch details
      final detailsData = await supabase
          .from('program_exercise_details')
          .select()
          .eq('program_exercise_id', programEx['id'])
          .maybeSingle();

      if (detailsData == null) continue;

      final detail = _DetailInline.fromMap(detailsData);

      // Category
      final categoryAssociations =
      exerciseData['exercise_category_association'] as List?;
      int? categoryId;
      String? categoryName;
      if (categoryAssociations != null && categoryAssociations.isNotEmpty) {
        final catData = categoryAssociations.first['exercise_categories'];
        categoryId = catData?['id'] as int?;
        categoryName = (catData?['name'] as String?)?.toLowerCase();
      }

      final sets = detail.sets;
      final minQ = detail.minQuantity;
      final maxQ = detail.maxQuantity;
      final durationType = detail.durationType;

      // ── Progressive overload for main exercise ───────────────────
      final baseSetQty = detail.resolvedSetQuantities();
      final prevSets = previousPerformance[exerciseId] ?? {};
      final progressedSetQty = _progressSets(
        sets: sets,
        baseQuantities: baseSetQty,
        previousBySetIndex: prevSets,
      );
      developer.log(
          "  Exercise $exerciseId: base=$baseSetQty -> progressed=$progressedSetQty");

      // ── Alternative ──────────────────────────────────────────────
      Map<String, dynamic>? alternativeExercise;
      if (detail.alternativeExerciseId != null) {
        alternativeExercise = await _fetchExercise(
          exerciseId: detail.alternativeExerciseId!,
          sets: detail.alternativeSet ?? sets,
          setQuantities: List.filled(
              detail.alternativeSet ?? sets,
              detail.minAlternative ?? minQ),
          minQ: detail.minAlternative ?? minQ,
          maxQ: detail.maxAlternative ?? maxQ,
          durationType: detail.alternativeDurationType ?? durationType,
        );
      }

      // ── Superset partner ─────────────────────────────────────────
      Map<String, dynamic>? supersetPartner;
      if (detail.supersetExerciseId != null) {
        final baseSupersetQty = detail.resolvedSupersetSetQuantities();
        final prevSupersetSets =
            previousPerformance[detail.supersetExerciseId!] ?? {};
        final progressedSupersetQty = _progressSets(
          sets: sets,
          baseQuantities: baseSupersetQty,
          previousBySetIndex: prevSupersetSets,
        );
        developer.log(
            "  Superset partner ${detail.supersetExerciseId}: base=$baseSupersetQty -> progressed=$progressedSupersetQty");

        supersetPartner = await _fetchExercise(
          exerciseId: detail.supersetExerciseId!,
          sets: sets,
          setQuantities: progressedSupersetQty,
          minQ: minQ,
          maxQ: maxQ,
          durationType: durationType,
        );
      }
      // ────────────────────────────────────────────────────────────

      generatedExercises.add({
        'id': programEx['id'],
        'exercise_id': exerciseId,
        'program_id': programId,
        'week_number': targetWeek,
        'day_number': targetDay,
        'name': exerciseData['name'] ?? 'Exercise',
        'media_url': exerciseData['media_url'],
        'coaching_cues': exerciseData['coaching_cues'] ?? '',
        'sets': sets,
        'set_quantities': progressedSetQty,
        'min_quantity': progressedSetQty.first,
        'max_quantity': progressedSetQty.reduce((a, b) => a > b ? a : b),
        'duration_type': durationType,
        'is_superset': detail.isSuperset,
        'has_alternative': detail.alternativeExerciseId != null,
        'alternative_exercise_id': detail.alternativeExerciseId,
        'alternative_exercise': alternativeExercise,
        'superset_exercise_id': detail.supersetExerciseId,
        'superset_partner': supersetPartner,
        'category_id': categoryId,
        'category_name': categoryName,
      });
    }

    // Sort by category
    generatedExercises.sort((a, b) {
      const order = {'warm-up': 0, 'main': 1, 'cool-down': 2};
      return (order[a['category_name']] ?? 1)
          .compareTo(order[b['category_name']] ?? 1);
    });

    developer.log(
        "Generated ${generatedExercises.length} exercises for Week $targetWeek Day $targetDay");
    return generatedExercises;
  }

  // ── Per-set progressive overload ─────────────────────────────────
  // For each set index, if there's a previous completion use that + 1.
  // If no previous completion for that set, fall back to base quantity.
  List<int> _progressSets({
    required int sets,
    required List<int> baseQuantities,
    required Map<int, int> previousBySetIndex,
  }) {
    final result = <int>[];
    for (int i = 1; i <= sets; i++) {
      final base = i <= baseQuantities.length
          ? baseQuantities[i - 1]
          : baseQuantities.last;
      final prev = previousBySetIndex[i];

      // If no previous log OR previous was 0 (a marker, not a real
      // performance), just use the prescribed base value.
      if (prev == null || prev <= 0) {
        result.add(base);
        continue;
      }

      // If the user actually performed reps, progress from whichever
      // is higher: the prescribed base, or their previous + 1.
      // This way:
      //   - Crushing the prescribed (prev >= base) → bump to prev + 1
      //   - Falling short of prescribed (prev < base) → stay at base
      result.add(prev + 1 > base ? prev + 1 : base);
    }
    return result;
  }

  // ── Analyze previous completions into { exerciseId -> { setIndex -> reps } }
  Map<int, Map<int, int>> _analyzePerformanceBySet(List logs) {
    final Map<int, Map<int, int>> performance = {};
    for (final log in logs) {
      final exerciseId = log['exercise_id'] as int?;
      final setIndex = log['set_index'] as int?;
      final reps = log['reps_completed'] as int?;
      if (exerciseId == null || setIndex == null || reps == null) continue;
      performance.putIfAbsent(exerciseId, () => {})[setIndex] = reps;
    }
    return performance;
  }

  // ── Fetch exercise name/media from exercises table ───────────────
  Future<Map<String, dynamic>?> _fetchExercise({
    required int exerciseId,
    required int sets,
    required List<int> setQuantities,
    required int minQ,
    required int maxQ,
    required String durationType,
  }) async {
    final ex = await supabase
        .from('exercises')
        .select('id, name, media_url, coaching_cues')
        .eq('id', exerciseId)
        .maybeSingle();

    if (ex == null) return null;

    return {
      'id': ex['id'],
      'exercise_id': exerciseId,
      'name': ex['name']?.toString().isNotEmpty == true
          ? ex['name']
          : 'Exercise',
      'media_url': ex['media_url']?.toString() ?? '',
      'coaching_cues': ex['coaching_cues'] ?? '',
      'sets': sets,
      'set_quantities': setQuantities,
      'min_quantity': minQ,
      'max_quantity': maxQ,
      'duration_type': durationType,
    };
  }
}

// ── Inline detail parser ─────────────────────────────────────────
class _DetailInline {
  final int sets;
  final int minQuantity;
  final int maxQuantity;
  final String durationType;
  final bool isSuperset;
  final int? alternativeExerciseId;
  final int? alternativeSet;
  final int? minAlternative;
  final int? maxAlternative;
  final String? alternativeDurationType;
  final List<int>? setQuantities;
  final int? supersetExerciseId;
  final List<int>? supersetSetQuantities;

  _DetailInline({
    required this.sets,
    required this.minQuantity,
    required this.maxQuantity,
    required this.durationType,
    required this.isSuperset,
    this.alternativeExerciseId,
    this.alternativeSet,
    this.minAlternative,
    this.maxAlternative,
    this.alternativeDurationType,
    this.setQuantities,
    this.supersetExerciseId,
    this.supersetSetQuantities,
  });

  List<int> resolvedSetQuantities() {
    if (setQuantities != null && setQuantities!.isNotEmpty) {
      return setQuantities!;
    }
    return List.filled(sets, minQuantity);
  }

  List<int> resolvedSupersetSetQuantities() {
    if (supersetSetQuantities != null && supersetSetQuantities!.isNotEmpty) {
      return supersetSetQuantities!;
    }
    return List.filled(sets, minQuantity);
  }

  factory _DetailInline.fromMap(Map<String, dynamic> map) {
    return _DetailInline(
      sets: map['sets'] ?? 1,
      minQuantity: map['min_quantity'] ?? 0,
      maxQuantity: map['max_quantity'] ?? map['min_quantity'] ?? 0,
      durationType: map['duration_type'] ?? 'reps',
      isSuperset: map['is_superset'] ?? false,
      alternativeExerciseId: map['alternative_exercise_id'],
      alternativeSet: map['alternative_sets'],
      minAlternative: map['min_alternative'],
      maxAlternative: map['max_alternative'],
      alternativeDurationType: map['alternative_duration_type'],
      setQuantities: _parseIntArray(map['set_quantities']),
      supersetExerciseId: map['superset_exercise_id'],
      supersetSetQuantities: _parseIntArray(map['superset_set_quantities']),
    );
  }

  static List<int>? _parseIntArray(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => (e as num).toInt()).toList();
    return null;
  }
}