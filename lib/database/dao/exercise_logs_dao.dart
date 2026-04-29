import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/exercise_logs.dart';

part 'exercise_logs_dao.g.dart';

@DriftAccessor(tables: [ExerciseLogs])
class ExerciseLogsDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseLogsDaoMixin {
  ExerciseLogsDao(AppDatabase db) : super(db);

  Future<void> insertLog(ExerciseLogsCompanion entry) {
    return into(exerciseLogs).insert(entry);
  }

  Future<List<ExerciseLog>> getUnsyncedLogs() {
    return (select(exerciseLogs)
          ..where((t) => t.synced.equals(false)))
        .get();
  }

  Future<void> markSynced(String id) {
    return (update(exerciseLogs)..where((t) => t.id.equals(id))).write(
      const ExerciseLogsCompanion(synced: Value(true)),
    );
  }

  Future<void> clearSynced() {
    return (delete(exerciseLogs)..where((t) => t.synced.equals(true))).go();
  }
}