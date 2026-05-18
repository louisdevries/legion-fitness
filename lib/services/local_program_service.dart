import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_custom_program.dart';

class LocalProgramService {
  static const _key = 'local_custom_programs';

  static Future<List<LocalCustomProgram>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => LocalCustomProgram.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(LocalCustomProgram program) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadAll();
    final idx = current.indexWhere((p) => p.id == program.id);
    if (idx >= 0) {
      current[idx] = program;
    } else {
      current.add(program);
    }
    await prefs.setString(
        _key, jsonEncode(current.map((p) => p.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadAll();
    current.removeWhere((p) => p.id == id);
    await prefs.setString(
        _key, jsonEncode(current.map((p) => p.toJson()).toList()));
  }

  static Future<void> markSessionComplete(
      String programId, int week, int day) async {
    final current = await loadAll();
    final idx = current.indexWhere((p) => p.id == programId);
    if (idx < 0) return;
    current[idx] = current[idx].copyWithCompleted(week, day);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(current.map((p) => p.toJson()).toList()));
  }
}
