import 'package:drift/drift.dart';

class ExerciseLogs extends Table {
  TextColumn get id => text()(); // UUID

  IntColumn get programId => integer()();
  IntColumn get exerciseId => integer()();
  IntColumn get weekNumber => integer()();
  IntColumn get dayNumber => integer()();

  IntColumn get reps => integer().nullable()();
  IntColumn get seconds => integer().nullable()();
  RealColumn get weight => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  BoolColumn get synced =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}