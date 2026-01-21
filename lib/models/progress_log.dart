class ProgressLog {
  final int id;
  final int exerciseId;
  final int programId;
  final int weekNumber;
  final int dayNumber;
  final int repsCompleted;
  final double? weightUsedKg;
  final DateTime date;
  final String userId;

  ProgressLog({
    required this.id,
    required this.exerciseId,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    required this.repsCompleted,
    this.weightUsedKg,
    required this.date,
    required this.userId,
  });

  factory ProgressLog.fromMap(Map<String, dynamic> map) {
    return ProgressLog(
      id: map['id'] as int,
      exerciseId: map['exercise_id'] as int,
      programId: map['program_id'] as int,
      weekNumber: map['week_number'] as int,
      dayNumber: map['day_number'] as int,
      repsCompleted: map['reps_completed'] as int,
      weightUsedKg: map['weight_used_kg'] != null
          ? (map['weight_used_kg'] as num).toDouble()
          : null,
      date: DateTime.parse(map['date'] as String),
      userId: map['user_id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'program_id': programId,
      'week_number': weekNumber,
      'day_number': dayNumber,
      'reps_completed': repsCompleted,
      'weight_used_kg': weightUsedKg,
      'date': date.toIso8601String(),
      'user_id': userId,
    };
  }
}
