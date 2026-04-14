class WorkoutSession {
  final int programId;
  final int weekNumber;
  final int dayNumber;

  final int totalRequiredSets;
  final int completedSets;

  const WorkoutSession({
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    this.totalRequiredSets = 0,
    this.completedSets = 0,
  });

  WorkoutSession copyWith({
    int? totalRequiredSets,
    int? completedSets,
  }) {
    return WorkoutSession(
      programId: programId,
      weekNumber: weekNumber,
      dayNumber: dayNumber,
      totalRequiredSets: totalRequiredSets ?? this.totalRequiredSets,
      completedSets: completedSets ?? this.completedSets,
    );
  }
}