class ExerciseSetResult {
  final int setIndex;
  final int reps;
  final int? durationSeconds;
  final double? weight;

  const ExerciseSetResult({
    required this.setIndex,
    required this.reps,
    this.durationSeconds,
    this.weight,
  });

  Map<String, dynamic> toJson() {
    return {
      'setIndex': setIndex,
      'reps': reps,
      'durationSeconds': durationSeconds,
      'weight': weight,
    };
  }

  factory ExerciseSetResult.fromJson(Map<String, dynamic> json) {
    return ExerciseSetResult(
      setIndex: json['setIndex'],
      reps: json['reps'],
      durationSeconds: json['durationSeconds'],
      weight: json['weight'],
    );
  }
}