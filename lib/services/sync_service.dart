import 'dart:developer' as developer;
import '../database/app_database.dart';
import '../services/progress_service.dart';

class SyncService {
  static bool _isSyncing = false;

  static Future<void> trySync() async {
    if (_isSyncing) {
      developer.log('🔄 trySync: already syncing, skipping');
      return;
    }
    _isSyncing = true;
    try {
      await _syncPending();
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _syncPending() async {
    final db = AppDatabase.instance;
    final pending = await db.exerciseLogsDao.getUnsyncedLogs();
    developer.log('🔄 trySync: ${pending.length} unsynced log(s)');
    if (pending.isEmpty) return;

    for (final log in pending) {
      // programId=0 means a local-only custom program — mark synced immediately
      // so the entry doesn't pile up in the retry queue.
      if (log.programId == 0) {
        developer.log('🔄 trySync: skipping local-only log ${log.id} (programId=0)');
        await db.exerciseLogsDao.markSynced(log.id);
        continue;
      }
      try {
        await ProgressService.logExerciseCompletion(
          programId: log.programId,
          exerciseId: log.exerciseId,
          weekNumber: log.weekNumber,
          dayNumber: log.dayNumber,
          setIndex: log.setIndex,
          repsCompleted: log.repsCompleted,
        );
        await db.exerciseLogsDao.markSynced(log.id);
        developer.log('🔄 trySync: synced log ${log.id} (exerciseId=${log.exerciseId})');
      } catch (e) {
        developer.log('🔄 trySync: FAILED to sync log ${log.id} (exerciseId=${log.exerciseId}): $e');
        continue;
      }
    }
  }
}