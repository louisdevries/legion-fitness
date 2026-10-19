// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_entries_dao.dart';

// ignore_for_file: type=lint
mixin _$MealEntriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $MealEntriesTable get mealEntries => attachedDatabase.mealEntries;
  MealEntriesDaoManager get managers => MealEntriesDaoManager(this);
}

class MealEntriesDaoManager {
  final _$MealEntriesDaoMixin _db;
  MealEntriesDaoManager(this._db);
  $$MealEntriesTableTableManager get mealEntries =>
      $$MealEntriesTableTableManager(_db.attachedDatabase, _db.mealEntries);
}
