import '../models/workout_session.dart';

class WorkoutEngineService {
  WorkoutSession session;

  WorkoutEngineService({
    required this.session,
  });

  // ─────────────────────────────
  // SET TRACKING
  // ─────────────────────────────

  void logSet() {
    session = session.copyWith(
      completedSets: session.completedSets + 1,
    );
  }

  void undoSet() {
    final current = session.completedSets;
    session = session.copyWith(
      completedSets: current > 0 ? current - 1 : 0,
    );
  }

  void reset() {
    session = session.copyWith(
      completedSets: 0,
    );
  }

  // ─────────────────────────────
  // PROGRESS
  // ─────────────────────────────

  double get progress {
    if (session.totalRequiredSets == 0) return 0.0;
    return session.completedSets / session.totalRequiredSets;
  }

  String get progressText {
    return '${session.completedSets} / ${session.totalRequiredSets}';
  }

  int get remainingSets {
    return (session.totalRequiredSets - session.completedSets)
        .clamp(0, session.totalRequiredSets);
  }

  // ─────────────────────────────
  // COMPLETION RULE (SINGLE SOURCE OF TRUTH)
  // ─────────────────────────────

  bool isWorkoutComplete() {
    return session.completedSets >= session.totalRequiredSets;
  }

  bool isAlmostComplete() {
    if (session.totalRequiredSets == 0) return false;
    return session.completedSets >= session.totalRequiredSets - 1;
  }

  // ─────────────────────────────
  // DEBUG HELPERS (REMOVE LATER IF YOU WANT)
  // ─────────────────────────────

  void debugPrintState() {
    print('WorkoutEngineState: '
        '${session.completedSets}/${session.totalRequiredSets}');
  }
}