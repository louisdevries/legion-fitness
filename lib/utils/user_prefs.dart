import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPrefs {
  /// Returns the per-user namespaced key. For signed-out users this
  /// returns a 'guest' key so guests still get their own slot rather
  /// than leaking into another user's data.
  static String _key(String name) {
    final user = Supabase.instance.client.auth.currentUser;
    final id = user?.id ?? 'guest';
    return '${id}__$name';
  }

  static Future<int?> getInt(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(name));
  }

  static Future<void> setInt(String name, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(name), value);
  }

  static Future<void> remove(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(name));
  }
}