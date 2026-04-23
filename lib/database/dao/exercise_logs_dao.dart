import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/exercise_logs.dart';

part 'exercise_logs_dao.g.dart';

@DriftAccessor(tables: [ExerciseLogs])
class ExerciseLogsDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseLogsDaoMixin {
  ExerciseLogsDao(AppDatabase db) : super(db);

  // ─────────────────────────────────────────────
  // INSERT LOG
  // ─────────────────────────────────────────────

  Future<void> insertLog(ExerciseLogsCompanion entry) {
    return into(exerciseLogs).insert(entry);
  }

  // ─────────────────────────────────────────────
  // GET UNSYNCED
  // ─────────────────────────────────────────────

  Future<List<ExerciseLog>> getUnsyncedLogs() {
    return (select(exerciseLogs)
      ..where((t) => t.synced.equals(false)))
        .get();
  }

  // ─────────────────────────────────────────────
  // MARK AS SYNCED
  // ─────────────────────────────────────────────

  Future<void> markSynced(String id) {
    return (update(exerciseLogs)..where((t) => t.id.equals(id))).write(
      const ExerciseLogsCompanion(
        synced: Value(true),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // DELETE SYNCED (optional cleanup)
  // ─────────────────────────────────────────────

  Future<void> clearSynced() {
    return (delete(exerciseLogs)
      ..where((t) => t.synced.equals(true)))
        .go();
  }
}