import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  static Future<bool> login(String email, String password) async {
    await _storage.write(key: "token", value: "fake-token");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_email", email);
    await prefs.setString("user_name", email.split('@')[0]); // temp name
    return true;
  }

  static Future<bool> register(String name, String email, String password) async {
    await _storage.write(key: "token", value: "fake-token");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_email", email);
    await prefs.setString("user_name", name);
    return true;
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_name");
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_email");
  }

  // ✅ Add this:
  static Future<String?> getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<void> logout() async {
    await _storage.delete(key: "token");
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
