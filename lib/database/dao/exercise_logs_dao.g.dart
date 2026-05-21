// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_logs_dao.dart';

// ignore_for_file: type=lint
mixin _$ExerciseLogsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExerciseLogsTable get exerciseLogs => attachedDatabase.exerciseLogs;
  ExerciseLogsDaoManager get managers => ExerciseLogsDaoManager(this);
}

class ExerciseLogsDaoManager {
  final _$ExerciseLogsDaoMixin _db;
  ExerciseLogsDaoManager(this._db);
  $$ExerciseLogsTableTableManager get exerciseLogs =>
      $$ExerciseLogsTableTableManager(_db.attachedDatabase, _db.exerciseLogs);
}
