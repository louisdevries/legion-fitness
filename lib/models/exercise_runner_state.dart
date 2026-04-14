class ExerciseRunnerState {
  final int currentIndex;
  final int currentSet;
  final int remainingSeconds;
  final int totalSeconds;
  final bool isPaused;
  final bool isResting;
  final bool mediaReady;
  final bool usingAlternative;
  final int lastSelectedReps;
  final int lastSelectedSeconds;
  final int completedSets;

  const ExerciseRunnerState({
    this.currentIndex = 0,
    this.currentSet = 1,
    this.remainingSeconds = 0,
    this.totalSeconds = 1,
    this.isPaused = false,
    this.isResting = false,
    this.mediaReady = false,
    this.usingAlternative = false,
    this.lastSelectedReps = 1,
    this.lastSelectedSeconds = 0,
    this.completedSets = 0,
  });

  ExerciseRunnerState copyWith({
    int? currentIndex,
    int? currentSet,
    int? remainingSeconds,
    int? totalSeconds,
    bool? isPaused,
    bool? isResting,
    bool? mediaReady,
    bool? usingAlternative,
    int? lastSelectedReps,
    int? lastSelectedSeconds,
    int? completedSets,
  }) {
    return ExerciseRunnerState(
      currentIndex: currentIndex ?? this.currentIndex,
      currentSet: currentSet ?? this.currentSet,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      isPaused: isPaused ?? this.isPaused,
      isResting: isResting ?? this.isResting,
      mediaReady: mediaReady ?? this.mediaReady,
      usingAlternative: usingAlternative ?? this.usingAlternative,
      lastSelectedReps: lastSelectedReps ?? this.lastSelectedReps,
      lastSelectedSeconds: lastSelectedSeconds ?? this.lastSelectedSeconds,
      completedSets: completedSets ?? this.completedSets,
    );
  }
}