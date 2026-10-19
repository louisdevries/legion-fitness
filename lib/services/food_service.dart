import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/api_keys.dart';
import '../database/app_database.dart';
import '../models/food.dart';
import '../models/meal_log.dart';

/// Foods and meal logging. Meal logs are local-first: they're written to
/// SQLite, shown from there, and pushed to Supabase by [syncPending], so the
/// Meals screen works offline.
class FoodService {
  static final _client = Supabase.instance.client;
  static final _dao = AppDatabase.instance.mealEntriesDao;
  static const _uuid = Uuid();

  // Open Food Facts asks every app to identify itself.
  static const _userAgent = 'LegionFitness/1.0.0 (Flutter; Android/iOS)';

  static const _offFields =
      'code,product_name,brands,nutriments,serving_quantity,image_front_small_url';

  static bool _isSyncing = false;

  // Anything other than a PostgREST error means we never reached the
  // database (no connection, timeout, DNS…).
  static bool _isOffline(Object e) => e is! PostgrestException;

  // ── Foods ───────────────────────────────────────────────────────

  /// Finds a food by barcode: the user's own entry first, then the shared
  /// Open Food Facts cache, then the Open Food Facts API (caching the result).
  /// Offline, falls back to foods this device has logged before.
  ///
  /// Returns null when the product is unknown or has no calorie data — the
  /// UI should then let the user enter the label values via [createCustomFood].
  static Future<Food?> lookupBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;

    try {
      final cached = await _findCached(code);
      if (cached != null) return cached;
    } catch (e) {
      if (!_isOffline(e)) rethrow;
      final local = await _dao.findByBarcode(code);
      return local == null ? null : _foodFromEntry(local);
    }

    final fetched = await _fetchFromOpenFoodFacts(code);
    if (fetched == null) return null;

    return ensureCached(fetched);
  }

  /// Saves a food the user typed in from the label. Private to them.
  ///
  /// Offline, returns the food without an id; logging it still works and
  /// [syncPending] creates it in Supabase later.
  static Future<Food> createCustomFood(Food food) async {
    final userFood = Food(
      source: 'user',
      barcode: food.barcode,
      name: food.name,
      brand: food.brand,
      kcal100g: food.kcal100g,
      protein100g: food.protein100g,
      carbs100g: food.carbs100g,
      fat100g: food.fat100g,
      fiber100g: food.fiber100g,
      sugar100g: food.sugar100g,
      salt100g: food.salt100g,
      servingG: food.servingG,
    );
    try {
      final row = await _client
          .from('foods')
          .insert(userFood.toInsertMap())
          .select()
          .single();
      return Food.fromMap(row);
    } catch (e) {
      if (!_isOffline(e)) rethrow;
      return userFood;
    }
  }

  /// Makes sure an Open Food Facts or USDA food has a row in our foods
  /// table (search results arrive without one).
  static Future<Food> ensureCached(Food food) async {
    if (food.id != null) return food;

    final usda = food.isFromUsda;
    final existing = await _client
        .from('foods')
        .select()
        .eq('source', food.source)
        .eq(usda ? 'fdc_id' : 'barcode', usda ? food.fdcId! : food.barcode!)
        .maybeSingle();
    if (existing != null) return Food.fromMap(existing);

    // USDA search results don't include portions; the detail call does.
    var toInsert = food;
    if (usda) {
      final (grams, label) = await _fetchUsdaPortion(food.fdcId!);
      toInsert = food.withServing(grams, label);
    }

    try {
      final row = await _client
          .from('foods')
          .insert(toInsert.toInsertMap())
          .select()
          .single();
      return Food.fromMap(row);
    } on PostgrestException catch (e) {
      // 23505 = another user cached it a moment ago — use their row.
      if (e.code != '23505') rethrow;
      final row = await _client
          .from('foods')
          .select()
          .eq('source', food.source)
          .eq(usda ? 'fdc_id' : 'barcode', usda ? food.fdcId! : food.barcode!)
          .single();
      return Food.fromMap(row);
    }
  }

  static bool get isUsdaConfigured => usdaApiKey.isNotEmpty;

  /// Searches USDA FoodData Central for generic foods (Foundation and SR
  /// Legacy — no US branded products, OFF covers those).
  /// Results have no id yet — pass the chosen one through [ensureCached].
  static Future<List<Food>> searchUsda(String query) async {
    final q = query.trim();
    if (q.isEmpty || !isUsdaConfigured) return [];

    final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'api_key': usdaApiKey,
      'query': q,
      'dataType': 'Foundation,SR Legacy',
      'pageSize': '30',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('USDA search failed (${res.statusCode})');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final foods = (body['foods'] as List?) ?? [];
    return foods
        .map((f) => _foodFromUsda(f as Map<String, dynamic>))
        .whereType<Food>()
        .toList();
  }

  /// Searches foods already in our database — the user's custom foods and
  /// anything previously cached from Open Food Facts. Offline, searches
  /// foods this device has logged.
  static Future<List<Food>> searchFoods(String query) async {
    // Characters that would break PostgREST's or() filter syntax.
    final q = query.replaceAll(RegExp(r'[,()%*]'), ' ').trim();
    if (q.isEmpty) return [];

    try {
      final rows = await _client
          .from('foods')
          .select()
          .or('name.ilike.%$q%,brand.ilike.%$q%')
          .order('name')
          .limit(30);
      return rows.map(Food.fromMap).toList();
    } catch (e) {
      if (!_isOffline(e)) rethrow;
      return _distinctFoods(await _dao.searchByName(q), limit: 30);
    }
  }

  /// Searches the Open Food Facts catalogue by name. Their search is rate
  /// limited (~10/min), so only call this on an explicit user action.
  /// Results have no id yet — pass the chosen one through [ensureCached].
  static Future<List<Food>> searchOpenFoodFacts(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.https('search.openfoodfacts.org', '/search', {
      'q': q,
      'page_size': '30',
      'fields': _offFields,
    });
    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Open Food Facts search failed (${res.statusCode})');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final hits = (body['hits'] as List?) ?? [];
    return hits
        .map((h) => _foodFromOffProduct(h as Map<String, dynamic>))
        .whereType<Food>()
        .toList();
  }

  /// Distinct foods from the user's most recent meal logs.
  static Future<List<Food>> getRecentFoods({int limit = 20}) async {
    try {
      final rows = await _client
          .from('meal_logs')
          .select('foods(*)')
          .order('logged_at', ascending: false)
          .limit(100);

      final seen = <int>{};
      final foods = <Food>[];
      for (final row in rows) {
        final food = Food.fromMap(row['foods'] as Map<String, dynamic>);
        if (seen.add(food.id!)) foods.add(food);
        if (foods.length >= limit) break;
      }
      return foods;
    } catch (e) {
      if (!_isOffline(e)) rethrow;
      return _distinctFoods(await _dao.getRecent(), limit: limit);
    }
  }

  // ── Meal logs (local-first) ─────────────────────────────────────

  static Future<void> logMeal({
    required Food food,
    required String mealType, // breakfast | lunch | dinner | snack
    required double grams,
    DateTime? loggedAt,
  }) async {
    await _dao.upsertEntry(MealEntriesCompanion.insert(
      id: _uuid.v4(),
      foodRemoteId: Value(food.id),
      mealType: mealType,
      grams: grams,
      loggedAt: loggedAt ?? DateTime.now(),
      foodSource: food.source,
      foodBarcode: Value(food.barcode),
      foodName: food.name,
      foodBrand: Value(food.brand),
      kcal100g: food.kcal100g,
      protein100g: Value(food.protein100g),
      carbs100g: Value(food.carbs100g),
      fat100g: Value(food.fat100g),
      fiber100g: Value(food.fiber100g),
      sugar100g: Value(food.sugar100g),
      salt100g: Value(food.salt100g),
      servingG: Value(food.servingG),
      servingLabel: Value(food.servingLabel),
    ));
    unawaited(syncPending());
  }

  static Future<void> updateMealLog({
    required String id,
    required double grams,
    required String mealType,
  }) async {
    final entry = await _dao.getEntry(id);
    if (entry == null) return;
    await _dao.upsertEntry(entry
        .copyWith(grams: grams, mealType: mealType, synced: false)
        .toCompanion(false));
    unawaited(syncPending());
  }

  static Future<void> deleteMealLog(String id) async {
    final entry = await _dao.getEntry(id);
    if (entry == null) return;
    await _dao.upsertEntry(
        entry.copyWith(deleted: true, synced: false).toCompanion(false));
    unawaited(syncPending());
  }

  /// Meal logs for the local calendar day containing [day], from the
  /// device. Call [refreshDay] to pull changes from other devices first.
  static Future<List<MealLog>> getMealsForDay(DateTime day) async {
    final (start, end) = _dayRange(day);
    final entries = await _dao.getEntriesBetween(start, end);
    return entries.where((e) => !e.deleted).map(_mealLogFromEntry).toList();
  }

  /// Pushes pending changes, then replaces this day's synced entries with
  /// what Supabase has. Returns false if offline.
  static Future<bool> refreshDay(DateTime day) async {
    await syncPending();

    final (start, end) = _dayRange(day);
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _client
          .from('meal_logs')
          .select('*, foods(*)')
          .gte('logged_at', start.toUtc().toIso8601String())
          .lt('logged_at', end.toUtc().toIso8601String());
    } catch (e) {
      if (!_isOffline(e)) rethrow;
      return false;
    }

    final remoteById = {for (final r in rows) r['client_id'] as String: r};
    final local = await _dao.getEntriesBetween(start, end);
    final localById = {for (final e in local) e.id: e};

    // Synced locally but gone remotely → deleted on another device.
    for (final e in local) {
      if (e.synced && !remoteById.containsKey(e.id)) {
        await _dao.deleteEntry(e.id);
      }
    }
    for (final r in rows) {
      final existing = localById[r['client_id']];
      if (existing != null && !existing.synced) continue; // local edit wins
      await _dao.upsertEntry(_entryFromRemote(r));
    }
    return true;
  }

  /// Pushes unsynced meal entries (creates, edits, deletes) to Supabase.
  /// Safe to call often; stops quietly when offline.
  static Future<void> syncPending() async {
    if (_isSyncing || _client.auth.currentUser == null) return;
    _isSyncing = true;
    try {
      for (final entry in await _dao.getUnsynced()) {
        try {
          await _syncEntry(entry);
        } catch (e) {
          if (_isOffline(e)) return; // try again next time
          debugPrint('Meal sync failed for ${entry.id}: $e');
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  // ── Internals ────────────────────────────────────────────────────

  static Future<void> _syncEntry(MealEntry entry) async {
    if (entry.deleted) {
      await _client.from('meal_logs').delete().eq('client_id', entry.id);
      await _dao.deleteEntry(entry.id);
      return;
    }

    var foodId = entry.foodRemoteId;
    if (foodId == null) {
      // Custom food created while offline.
      foodId = await _createRemoteFoodFor(entry);
      await _dao.setFoodRemoteId(
        foodName: entry.foodName,
        foodBarcode: entry.foodBarcode,
        foodRemoteId: foodId,
      );
    }

    await _client.from('meal_logs').upsert({
      'client_id': entry.id,
      'food_id': foodId,
      'meal_type': entry.mealType,
      'grams': entry.grams,
      'logged_at': entry.loggedAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'client_id');

    // Only mark synced if it wasn't edited while we were pushing.
    final current = await _dao.getEntry(entry.id);
    if (current != null &&
        !current.deleted &&
        current.grams == entry.grams &&
        current.mealType == entry.mealType) {
      await _dao.markSynced(entry.id);
    }
  }

  static Future<int> _createRemoteFoodFor(MealEntry entry) async {
    final food = _foodFromEntry(entry);
    try {
      final row = await _client
          .from('foods')
          .insert({...food.toInsertMap(), 'source': 'user'})
          .select('id')
          .single();
      return (row['id'] as num).toInt();
    } on PostgrestException catch (e) {
      // The user already has a food for this barcode — reuse it.
      if (e.code != '23505' || entry.foodBarcode == null) rethrow;
      final row = await _client
          .from('foods')
          .select('id')
          .eq('source', 'user')
          .eq('created_by', _client.auth.currentUser!.id)
          .eq('barcode', entry.foodBarcode!)
          .single();
      return (row['id'] as num).toInt();
    }
  }

  static (DateTime, DateTime) _dayRange(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return (start, start.add(const Duration(days: 1)));
  }

  static Food _foodFromEntry(MealEntry e) => Food(
        id: e.foodRemoteId,
        source: e.foodSource,
        barcode: e.foodBarcode,
        name: e.foodName,
        brand: e.foodBrand,
        kcal100g: e.kcal100g,
        protein100g: e.protein100g,
        carbs100g: e.carbs100g,
        fat100g: e.fat100g,
        fiber100g: e.fiber100g,
        sugar100g: e.sugar100g,
        salt100g: e.salt100g,
        servingG: e.servingG,
        servingLabel: e.servingLabel,
      );

  static MealLog _mealLogFromEntry(MealEntry e) => MealLog(
        id: e.id,
        mealType: e.mealType,
        grams: e.grams,
        loggedAt: e.loggedAt,
        food: _foodFromEntry(e),
        synced: e.synced,
      );

  static MealEntriesCompanion _entryFromRemote(Map<String, dynamic> r) {
    final f = Food.fromMap(r['foods'] as Map<String, dynamic>);
    return MealEntriesCompanion.insert(
      id: r['client_id'] as String,
      foodRemoteId: Value(f.id),
      mealType: r['meal_type'] as String,
      grams: (r['grams'] as num).toDouble(),
      loggedAt: DateTime.parse(r['logged_at'] as String).toLocal(),
      foodSource: f.source,
      foodBarcode: Value(f.barcode),
      foodName: f.name,
      foodBrand: Value(f.brand),
      kcal100g: f.kcal100g,
      protein100g: Value(f.protein100g),
      carbs100g: Value(f.carbs100g),
      fat100g: Value(f.fat100g),
      fiber100g: Value(f.fiber100g),
      sugar100g: Value(f.sugar100g),
      salt100g: Value(f.salt100g),
      servingG: Value(f.servingG),
      servingLabel: Value(f.servingLabel),
      synced: const Value(true),
    );
  }

  /// One food per distinct product, keeping the order given.
  static List<Food> _distinctFoods(List<MealEntry> entries, {required int limit}) {
    final seen = <String>{};
    final foods = <Food>[];
    for (final e in entries) {
      final key = e.foodRemoteId?.toString() ??
          '${e.foodName}|${e.foodBrand}|${e.foodBarcode}';
      if (seen.add(key)) foods.add(_foodFromEntry(e));
      if (foods.length >= limit) break;
    }
    return foods;
  }

  static Future<Food?> _findCached(String code) async {
    // RLS only returns OFF rows and the current user's own rows.
    final rows = await _client.from('foods').select().eq('barcode', code);
    if (rows.isEmpty) return null;

    final foods = rows.map(Food.fromMap).toList();
    return foods.firstWhere(
      (f) => f.source == 'user',
      orElse: () => foods.first,
    );
  }

  static Future<Food?> _fetchFromOpenFoodFacts(String code) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$code',
      {'fields': _offFields},
    );

    final http.Response res;
    try {
      res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('OFF lookup failed for $code: $e');
      return null;
    }

    // OFF returns 404 for unknown barcodes.
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1) return null;

    final product = body['product'] as Map<String, dynamic>? ?? {};
    return _foodFromOffProduct({...product, 'code': code});
  }

  /// Builds a Food from an OFF product (product API or search hit).
  /// Null when it lacks a barcode, name or calories.
  static Food? _foodFromOffProduct(Map<String, dynamic> product) {
    final code = product['code'] as String?;
    final n = product['nutriments'] as Map<String, dynamic>? ?? {};

    // Some products only have kJ.
    final kj = _num(n['energy-kj_100g']) ?? _num(n['energy_100g']);
    final kcal = _num(n['energy-kcal_100g']) ?? (kj != null ? kj / 4.184 : null);
    final name = (product['product_name'] as String?)?.trim();
    if (code == null || kcal == null || name == null || name.isEmpty) {
      return null;
    }

    // The product API gives "A, B"; search gives ["A", "B"].
    final rawBrands = product['brands'];
    final brand = (rawBrands is List
            ? (rawBrands.isEmpty ? null : rawBrands.first as String?)
            : (rawBrands as String?)?.split(',').first)
        ?.trim();

    return Food(
      source: 'off',
      barcode: code,
      name: name,
      brand: (brand == null || brand.isEmpty) ? null : brand,
      kcal100g: kcal,
      protein100g: _num(n['proteins_100g']),
      carbs100g: _num(n['carbohydrates_100g']),
      fat100g: _num(n['fat_100g']),
      fiber100g: _num(n['fiber_100g']),
      sugar100g: _num(n['sugars_100g']),
      salt100g: _num(n['salt_100g']),
      servingG: _num(product['serving_quantity']),
      imageUrl: product['image_front_small_url'] as String?,
    );
  }

  // USDA nutrient ids. Search results give nutrients per 100 g for
  // Foundation and SR Legacy foods.
  static const _usdaKcal = 1008;
  static const _usdaKcalAtwaterGeneral = 2047;
  static const _usdaKcalAtwaterSpecific = 2048;
  static const _usdaKj = 1062;
  static const _usdaProtein = 1003;
  static const _usdaFat = 1004;
  static const _usdaCarbs = 1005;
  static const _usdaFiber = 1079;
  static const _usdaSugars = 2000;
  static const _usdaSodiumMg = 1093;

  static Food? _foodFromUsda(Map<String, dynamic> f) {
    final fdcId = (f['fdcId'] as num?)?.toInt();
    final name = (f['description'] as String?)?.trim();

    final values = <int, double>{};
    for (final n in (f['foodNutrients'] as List? ?? [])) {
      final id = (n['nutrientId'] as num?)?.toInt();
      final value = _num(n['value']);
      if (id != null && value != null) values[id] = value;
    }

    // Some Foundation foods only report Atwater energy, or only kJ.
    final kj = values[_usdaKj];
    final kcal = values[_usdaKcal] ??
        values[_usdaKcalAtwaterSpecific] ??
        values[_usdaKcalAtwaterGeneral] ??
        (kj != null ? kj / 4.184 : null);
    if (fdcId == null || name == null || name.isEmpty || kcal == null) {
      return null;
    }

    final sodiumMg = values[_usdaSodiumMg];
    return Food(
      source: 'usda',
      fdcId: fdcId,
      name: name,
      kcal100g: kcal,
      protein100g: values[_usdaProtein],
      carbs100g: values[_usdaCarbs],
      fat100g: values[_usdaFat],
      fiber100g: values[_usdaFiber],
      sugar100g: values[_usdaSugars],
      // Salt ≈ sodium × 2.5
      salt100g: sodiumMg == null ? null : sodiumMg * 2.5 / 1000,
    );
  }

  /// The food's most useful household portion, e.g. (50.3, "1 egg, whole
  /// without shell"). (null, null) if none or the call fails — the food is
  /// still usable by weight.
  static Future<(double?, String?)> _fetchUsdaPortion(int fdcId) async {
    try {
      final uri = Uri.https(
          'api.nal.usda.gov', '/fdc/v1/food/$fdcId', {'api_key': usdaApiKey});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return (null, null);

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final portions = (body['foodPortions'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .where((p) => _num(p['gramWeight']) != null)
          .toList();

      String unitOf(Map<String, dynamic> p) =>
          (p['measureUnit'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      // RACC is a regulatory reference amount, not a real portion.
      final real = portions.where((p) => unitOf(p) != 'RACC').toList();
      if (real.isEmpty) return (null, null);

      // Prefer a single unit ("1 egg") over fractions or cups.
      real.sort((a, b) {
        final aOne = _num(a['amount']) == 1 ? 0 : 1;
        final bOne = _num(b['amount']) == 1 ? 0 : 1;
        return aOne - bOne;
      });
      final p = real.first;

      final amount = _num(p['amount']) ?? 1;
      final unit = unitOf(p);
      final detail = (p['modifier'] as String?) ??
          (p['portionDescription'] as String?) ??
          '';
      final label = [
        amount == amount.roundToDouble()
            ? amount.toInt().toString()
            : amount.toString(),
        if (unit.isNotEmpty && unit != 'undetermined') unit,
        if (detail.isNotEmpty) detail,
      ].join(' ');

      return (_num(p['gramWeight']), label);
    } catch (e) {
      debugPrint('USDA portion lookup failed for $fdcId: $e');
      return (null, null);
    }
  }

  // OFF values arrive as numbers or numeric strings.
  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
