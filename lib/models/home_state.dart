class HomeState {
  final int? programId;
  final int currentWeek;
  final String? programName;
  final String? programImage;

  final Map<int, bool> completedDays; // Calendar days (1-7) where user worked out this week
  final Set<String> completedWorkoutDates; // ISO date strings when user worked out

  final int? nextWeek;
  final int? nextDay;

  final int daysPerWeek;

  // About the next day to train
  final String? nextDayTitle; // e.g. "Pull Day"
  final bool nextDayIsCardio;
  final int? nextDayExerciseCount;
  final int? nextDayMinutes; // estimate for workouts, minimum for cardio

  final double programProgress;
  final double weekProgress;

  final bool isLoading;

  HomeState({
    this.programId,
    this.currentWeek = 1,
    this.programName,
    this.programImage,
    Map<int, bool>? completedDays,
    Set<String>? completedWorkoutDates,
    this.nextWeek,
    this.nextDay,
    this.daysPerWeek = 0,
    this.nextDayTitle,
    this.nextDayIsCardio = false,
    this.nextDayExerciseCount,
    this.nextDayMinutes,
    this.programProgress = 0.0,
    this.weekProgress = 0.0,
    this.isLoading = true,
  })  : completedDays = completedDays ?? {},
        completedWorkoutDates = completedWorkoutDates ?? {};

  HomeState copyWith({
    int? programId,
    int? currentWeek,
    String? programName,
    String? programImage,
    Map<int, bool>? completedDays,
    Set<String>? completedWorkoutDates,
    int? nextWeek,
    int? nextDay,
    int? daysPerWeek,
    String? nextDayTitle,
    bool? nextDayIsCardio,
    int? nextDayExerciseCount,
    int? nextDayMinutes,
    double? programProgress,
    double? weekProgress,
    bool? isLoading,
  }) {
    return HomeState(
      programId: programId ?? this.programId,
      currentWeek: currentWeek ?? this.currentWeek,
      programName: programName ?? this.programName,
      programImage: programImage ?? this.programImage,
      completedDays: completedDays ?? this.completedDays,
      completedWorkoutDates: completedWorkoutDates ?? this.completedWorkoutDates,
      nextWeek: nextWeek ?? this.nextWeek,
      nextDay: nextDay ?? this.nextDay,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      nextDayTitle: nextDayTitle ?? this.nextDayTitle,
      nextDayIsCardio: nextDayIsCardio ?? this.nextDayIsCardio,
      nextDayExerciseCount: nextDayExerciseCount ?? this.nextDayExerciseCount,
      nextDayMinutes: nextDayMinutes ?? this.nextDayMinutes,
      programProgress: programProgress ?? this.programProgress,
      weekProgress: weekProgress ?? this.weekProgress,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isProgramComplete => nextWeek == null && nextDay == null;
}
