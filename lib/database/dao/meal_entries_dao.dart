import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/meal_entries.dart';

part 'meal_entries_dao.g.dart';

@DriftAccessor(tables: [MealEntries])
class MealEntriesDao extends DatabaseAccessor<AppDatabase>
    with _$MealEntriesDaoMixin {
  MealEntriesDao(super.db);

  Future<void> upsertEntry(MealEntriesCompanion entry) {
    return into(mealEntries).insertOnConflictUpdate(entry);
  }

  Future<MealEntry?> getEntry(String id) {
    return (select(mealEntries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Entries in [start, end), including ones pending deletion.
  Future<List<MealEntry>> getEntriesBetween(DateTime start, DateTime end) {
    return (select(mealEntries)
          ..where((t) =>
              t.loggedAt.isBiggerOrEqualValue(start) &
              t.loggedAt.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .get();
  }

  Future<List<MealEntry>> getUnsynced() {
    return (select(mealEntries)..where((t) => t.synced.equals(false))).get();
  }

  Future<List<MealEntry>> getRecent({int limit = 200}) {
    return (select(mealEntries)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
          ..limit(limit))
        .get();
  }

  Future<MealEntry?> findByBarcode(String barcode) {
    return (select(mealEntries)
          ..where((t) => t.foodBarcode.equals(barcode))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<MealEntry>> searchByName(String query) {
    final pattern = '%${query.toLowerCase()}%';
    return (select(mealEntries)
          ..where((t) =>
              t.foodName.lower().like(pattern) |
              t.foodBrand.lower().like(pattern))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
          ..limit(200))
        .get();
  }

  Future<void> markSynced(String id) {
    return (update(mealEntries)..where((t) => t.id.equals(id))).write(
      const MealEntriesCompanion(synced: Value(true)),
    );
  }

  /// Once a custom food created offline exists in Supabase, point every
  /// entry that used it at the new row.
  Future<void> setFoodRemoteId({
    required String foodName,
    required String? foodBarcode,
    required int foodRemoteId,
  }) {
    return (update(mealEntries)
          ..where((t) =>
              t.foodRemoteId.isNull() &
              t.foodName.equals(foodName) &
              (foodBarcode == null
                  ? t.foodBarcode.isNull()
                  : t.foodBarcode.equals(foodBarcode))))
        .write(MealEntriesCompanion(foodRemoteId: Value(foodRemoteId)));
  }

  Future<void> deleteEntry(String id) {
    return (delete(mealEntries)..where((t) => t.id.equals(id))).go();
  }
}
