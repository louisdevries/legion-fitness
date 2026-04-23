import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart'; // ✅ REQUIRED for Value()

import '../database/app_database.dart';

class LocalWorkoutService {
  static final AppDatabase _db = AppDatabase.instance;

  static final _uuid = Uuid(); // ❗ remove const (safer)

  // ─────────────────────────────────────────────
  // MAIN ENTRY: log a completed set locally
  // ─────────────────────────────────────────────

  static Future<void> logSet({
    required Map<String, dynamic> exercise,
    required bool isTimed,
    required int reps,
    required int seconds,
    double? weightUsedKg,
  }) async {
    final now = DateTime.now();

    await _db.into(_db.exerciseLogs).insert(
      ExerciseLogsCompanion.insert(
        id: _uuid.v4(),

        programId: exercise['program_id'] as int,
        exerciseId: exercise['exercise_id'] as int,
        weekNumber: exercise['week_number'] as int,
        dayNumber: exercise['day_number'] as int,

        // ✅ FIX: wrap nullable values
        reps: Value(isTimed ? null : reps),
        seconds: Value(isTimed ? seconds : null),
        weight: Value(weightUsedKg),

        createdAt: now,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FETCH UNSYNCED (used by SyncService)
  // ─────────────────────────────────────────────

  static Future<List<ExerciseLog>> getUnsynced() {
    return (_db.select(_db.exerciseLogs)
      ..where((t) => t.synced.equals(false)))
        .get();
  }

  // ─────────────────────────────────────────────
  // MARK AS SYNCED
  // ─────────────────────────────────────────────

  static Future<void> markAsSynced(String id) async {
    await (_db.update(_db.exerciseLogs)..where((t) => t.id.equals(id)))
        .write(
      const ExerciseLogsCompanion(
        synced: Value(true), // ✅ now works (import fixed)
      ),
    );
  }

  // ─────────────────────────────────────────────
  // OPTIONAL: CLEAR OLD DATA (cleanup)
  // ─────────────────────────────────────────────

  static Future<void> clearSyncedLogs() async {
    await (_db.delete(_db.exerciseLogs)
      ..where((t) => t.synced.equals(true)))
        .go();
  }
}