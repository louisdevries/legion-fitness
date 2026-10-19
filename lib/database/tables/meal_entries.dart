import 'package:drift/drift.dart';

/// Local copy of meal_logs. Each entry carries a snapshot of its food so the
/// Meals screen works offline, and so an entry for a custom food created
/// offline can be synced later (the food is created first, then the log).
class MealEntries extends Table {
  TextColumn get id => text()(); // = meal_logs.client_id
  IntColumn get foodRemoteId => integer().nullable()(); // null until the food exists in Supabase
  TextColumn get mealType => text()();
  RealColumn get grams => real()();
  DateTimeColumn get loggedAt => dateTime()();

  // Food snapshot
  TextColumn get foodSource => text()();
  TextColumn get foodBarcode => text().nullable()();
  TextColumn get foodName => text()();
  TextColumn get foodBrand => text().nullable()();
  RealColumn get kcal100g => real()();
  RealColumn get protein100g => real().nullable()();
  RealColumn get carbs100g => real().nullable()();
  RealColumn get fat100g => real().nullable()();
  RealColumn get fiber100g => real().nullable()();
  RealColumn get sugar100g => real().nullable()();
  RealColumn get salt100g => real().nullable()();
  RealColumn get servingG => real().nullable()();
  TextColumn get servingLabel => text().nullable()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  // Deleted locally; removed for good once the delete reaches Supabase.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
