class PendingCompletion {
  final int programId;
  final int weekNumber;
  final int dayNumber;
  final int exerciseId;
  final int setIndex;
  final int repsCompleted;
  final String localId;

  PendingCompletion({
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    required this.exerciseId,
    required this.setIndex,
    required this.repsCompleted,
    required this.localId,
  });

  Map<String, dynamic> toJson() => {
        'program_id': programId,
        'week_number': weekNumber,
        'day_number': dayNumber,
        'exercise_id': exerciseId,
        'set_index': setIndex,
        'reps_completed': repsCompleted,
        'local_id': localId,
      };

  factory PendingCompletion.fromJson(Map<String, dynamic> json) {
    return PendingCompletion(
      programId: json['program_id'],
      weekNumber: json['week_number'],
      dayNumber: json['day_number'],
      exerciseId: json['exercise_id'],
      setIndex: json['set_index'] ?? 1,
      repsCompleted: json['reps_completed'] ?? 0,
      localId: json['local_id'],
    );
  }
}