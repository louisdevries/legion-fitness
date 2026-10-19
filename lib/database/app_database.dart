import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dao/exercise_logs_dao.dart';
import 'dao/meal_entries_dao.dart';
import 'tables/exercise_logs.dart';
import 'tables/meal_entries.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ExerciseLogs,
    MealEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  // 🔥 Singleton instance (important for app-wide usage)
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  late final ExerciseLogsDao exerciseLogsDao =
  ExerciseLogsDao(this);

  late final MealEntriesDao mealEntriesDao = MealEntriesDao(this);

// ─────────────────────────────────────────────
// optional: migrations later
// ─────────────────────────────────────────────

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(exerciseLogs, exerciseLogs.setIndex);
        await m.addColumn(exerciseLogs, exerciseLogs.repsCompleted);
      }
      if (from < 3) {
        await m.createTable(mealEntries);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'legion_fitness.sqlite'));

    return NativeDatabase(file);
  });
}

