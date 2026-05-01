import 'exercise_set_result.dart';

class ExerciseRunnerState {
  final int currentIndex;
  final int currentSet;
  final bool isResting;
  final bool isPaused;
  final bool usingAlternative;
  final bool onSupersetPartner; // ← new

  final int remainingSeconds;
  final int totalSeconds;

  final int lastSelectedReps;
  final int lastSelectedSeconds;

  final int completedSets;

  final bool mediaReady;

  final List<int> currentSetReps;
  final List<ExerciseSetResult> completedSetsData;

  const ExerciseRunnerState({
    this.currentIndex = 0,
    this.currentSet = 1,
    this.isResting = false,
    this.isPaused = false,
    this.usingAlternative = false,
    this.onSupersetPartner = false, // ← new
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.lastSelectedReps = 0,
    this.lastSelectedSeconds = 0,
    this.completedSets = 0,
    this.mediaReady = false,
    this.currentSetReps = const [],
    this.completedSetsData = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'currentIndex': currentIndex,
      'currentSet': currentSet,
      'isResting': isResting,
      'isPaused': isPaused,
      'usingAlternative': usingAlternative,
      'onSupersetPartner': onSupersetPartner, // ← new
      'remainingSeconds': remainingSeconds,
      'totalSeconds': totalSeconds,
      'lastSelectedReps': lastSelectedReps,
      'lastSelectedSeconds': lastSelectedSeconds,
      'completedSets': completedSets,
      'mediaReady': mediaReady,
      'currentSetReps': currentSetReps,
    };
  }

  factory ExerciseRunnerState.fromJson(Map<String, dynamic> json) {
    return ExerciseRunnerState(
      currentIndex: json['currentIndex'] ?? 0,
      currentSet: json['currentSet'] ?? 1,
      isResting: json['isResting'] ?? false,
      isPaused: json['isPaused'] ?? false,
      usingAlternative: json['usingAlternative'] ?? false,
      onSupersetPartner: json['onSupersetPartner'] ?? false, // ← new
      remainingSeconds: json['remainingSeconds'] ?? 0,
      totalSeconds: json['totalSeconds'] ?? 0,
      lastSelectedReps: json['lastSelectedReps'] ?? 0,
      lastSelectedSeconds: json['lastSelectedSeconds'] ?? 0,
      completedSets: json['completedSets'] ?? 0,
      mediaReady: json['mediaReady'] ?? false,
      currentSetReps: List<int>.from(json['currentSetReps'] ?? []),
      completedSetsData: const [],
    );
  }

  ExerciseRunnerState copyWith({
    int? currentIndex,
    int? currentSet,
    bool? isResting,
    bool? isPaused,
    bool? usingAlternative,
    bool? onSupersetPartner, // ← new
    int? remainingSeconds,
    int? totalSeconds,
    int? lastSelectedReps,
    int? lastSelectedSeconds,
    int? completedSets,
    bool? mediaReady,
    List<int>? currentSetReps,
    List<ExerciseSetResult>? completedSetsData,
  }) {
    return ExerciseRunnerState(
      currentIndex: currentIndex ?? this.currentIndex,
      currentSet: currentSet ?? this.currentSet,
      isResting: isResting ?? this.isResting,
      isPaused: isPaused ?? this.isPaused,
      usingAlternative: usingAlternative ?? this.usingAlternative,
      onSupersetPartner: onSupersetPartner ?? this.onSupersetPartner, // ← new
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      lastSelectedReps: lastSelectedReps ?? this.lastSelectedReps,
      lastSelectedSeconds: lastSelectedSeconds ?? this.lastSelectedSeconds,
      completedSets: completedSets ?? this.completedSets,
      mediaReady: mediaReady ?? this.mediaReady,
      currentSetReps: currentSetReps ?? this.currentSetReps,
      completedSetsData: completedSetsData ?? this.completedSetsData,
    );
  }
}