import '../database/app_database.dart';
import '../services/progress_service.dart';
import 'local_workout_service.dart';

class SyncService {
  static bool _isSyncing = false;

  // ─────────────────────────────────────────────
  // PUBLIC ENTRY (safe trigger)
  // ─────────────────────────────────────────────

  static Future<void> trySync() async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      await _syncPending();
    } finally {
      _isSyncing = false;
    }
  }

  // ─────────────────────────────────────────────
  // CORE SYNC LOGIC
  // ─────────────────────────────────────────────

  static Future<void> _syncPending() async {
    final db = AppDatabase.instance;

    final pending = await db.exerciseLogsDao.getUnsyncedLogs();

    if (pending.isEmpty) return;

    for (final log in pending) {
      try {
        await ProgressService.logExercise(
          programId: log.programId,
          exerciseId: log.exerciseId,
          weekNumber: log.weekNumber,
          dayNumber: log.dayNumber,
          repsCompleted: log.reps ?? log.seconds ?? 0,
          weightUsedKg: log.weight,
        );

        // ✅ mark as synced locally
        await db.exerciseLogsDao.markSynced(log.id);
      } catch (e) {
        // ❌ stop on first failure (network likely down)
        break;
      }
    }
  }
}