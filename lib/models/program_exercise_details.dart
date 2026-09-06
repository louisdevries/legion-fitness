import '../utils/rep_scheme_utils.dart';

class ProgramExerciseDetail {
  final int id;
  final int programExerciseId;
  final int exerciseId;
  final int sets;
  final int minQuantity;
  final int maxQuantity;
  final String durationType;
  final bool isSuperset;
  final bool hasAlternative;
  final int? alternativeExerciseId;
  final int? alternativeSet;
  final int? minAlternative;
  final int? maxAlternative;
  final String? alternativeDurationType;
  final List<int>? setQuantities;
  final int? supersetExerciseId;
  final List<int>? supersetSetQuantities;
  final String? tempo;

  ProgramExerciseDetail({
    required this.id,
    required this.programExerciseId,
    required this.exerciseId,
    required this.sets,
    required this.minQuantity,
    required this.maxQuantity,
    required this.durationType,
    required this.isSuperset,
    required this.hasAlternative,
    this.alternativeExerciseId,
    this.alternativeSet,
    this.minAlternative,
    this.maxAlternative,
    this.alternativeDurationType,
    this.setQuantities,
    this.supersetExerciseId,
    this.supersetSetQuantities,
    this.tempo,
  });

  /// Returns per-set targets for the main exercise.
  /// If set_quantities is populated, use it directly. Otherwise spread
  /// min_quantity..max_quantity evenly across the sets.
  List<int> resolvedSetQuantities() {
    if (setQuantities != null && setQuantities!.isNotEmpty) {
      return setQuantities!;
    }
    return RepSchemeUtils.evenlySpaced(
      sets: sets,
      minQuantity: minQuantity,
      maxQuantity: maxQuantity,
    );
  }

  /// Returns per-set targets for the superset partner.
  /// Spreads min_quantity..max_quantity evenly across the sets if not set.
  List<int> resolvedSupersetSetQuantities() {
    if (supersetSetQuantities != null && supersetSetQuantities!.isNotEmpty) {
      return supersetSetQuantities!;
    }
    return RepSchemeUtils.evenlySpaced(
      sets: sets,
      minQuantity: minQuantity,
      maxQuantity: maxQuantity,
    );
  }

  factory ProgramExerciseDetail.fromMap(Map<String, dynamic> map) {
    return ProgramExerciseDetail(
      id: map['id'],
      programExerciseId: map['program_exercise_id'],
      exerciseId: map['exercise_id'],
      sets: map['sets'] ?? 1,
      minQuantity: map['min_quantity'] ?? 0,
      maxQuantity: map['max_quantity'] ?? map['min_quantity'] ?? 0,
      durationType: map['duration_type'] ?? 'reps',
      isSuperset: map['is_superset'] ?? false,
      hasAlternative: map['has_alternative'] ?? false,
      alternativeExerciseId: map['alternative_exercise_id'],
      alternativeSet: map['alternative_sets'],
      minAlternative: map['min_alternative'],
      maxAlternative: map['max_alternative'],
      alternativeDurationType: map['alternative_duration_type'],
      setQuantities: _parseIntArray(map['set_quantities']),
      supersetExerciseId: map['superset_exercise_id'],
      supersetSetQuantities: _parseIntArray(map['superset_set_quantities']),
      tempo: map['tempo'] as String?,
    );
  }

  static List<int>? _parseIntArray(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => (e as num).toInt()).toList();
    }
    return null;
  }
}