import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dao/exercise_logs_dao.dart';
import 'tables/exercise_logs.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ExerciseLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  // 🔥 Singleton instance (important for app-wide usage)
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  late final ExerciseLogsDao exerciseLogsDao =
  ExerciseLogsDao(this);

// ─────────────────────────────────────────────
// optional: migrations later
// ─────────────────────────────────────────────
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'legion_fitness.sqlite'));

    return NativeDatabase(file);
  });
}