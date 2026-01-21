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
  });

  factory ProgramExerciseDetail.fromMap(Map<String, dynamic> map) {
    return ProgramExerciseDetail(
      id: map['id'],
      programExerciseId: map['program_exercise_id'],
      exerciseId: map['exercise_id'],
      sets: map['sets'],
      minQuantity: map['min_quantity'],
      maxQuantity: map['max_quantity'],
      durationType: map['duration_type'],
      isSuperset: map['is_superset'] ?? false,
      hasAlternative: map['has_alternative'] ?? false,
      alternativeExerciseId: map['alternative_exercise_id'],
      alternativeSet: map['alternative_set'],
      minAlternative: map['min_alternative'],
      maxAlternative: map['max_alternative'],
      alternativeDurationType: map['alternative_duration_type'],
    );
  }
}
