class ProgramExercise {
  final int id;
  final int programId;
  final int exerciseId;
  final int weekNumber;
  final int dayNumber;

  ProgramExercise({
    required this.id,
    required this.programId,
    required this.exerciseId,
    required this.weekNumber,
    required this.dayNumber,
  });

  factory ProgramExercise.fromMap(Map<String, dynamic> map) {
    return ProgramExercise(
      id: map['id'],
      programId: map['program_id'],
      exerciseId: map['exercise_id'],
      weekNumber: map['week_number'],
      dayNumber: map['day_number'],
    );
  }
}
