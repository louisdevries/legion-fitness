import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

final supabase = Supabase.instance.client;
final _storage = FlutterSecureStorage();

class AuthService {
  /// Register a new user
  /// Returns null if successful, otherwise returns an error message
  static Future<String?> register(String name, String email, String password) async {
    try {
      // Check if email already exists
      final existing = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existing != null) return "Email already registered";

      // Hash password (SHA256 example, ideally use server-side hashing)
      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      final response = await supabase.from('users').insert({
        'email': email,
        'name': name,
        'username': email.split('@')[0],
        'password_hash': passwordHash,
        'is_paid_user': false,
        'is_admin': false,
      }).select().single();

      if (response == null) return "Failed to register";

      // Save token locally (just user id for now)
      await _storage.write(key: 'token', value: response['id']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);

      return null; // success
    } catch (e) {
      print("Register error: $e");
      return "An error occurred";
    }
  }

  /// Login existing user
  /// Returns null if successful, otherwise returns an error message
  static Future<String?> login(String email, String password) async {
    try {
      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      final response = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .eq('password_hash', passwordHash)
          .maybeSingle();

      if (response == null) return "Invalid email or password";

      await _storage.write(key: 'token', value: response['id']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', response['name'] ?? email.split('@')[0]);

      return null; // success
    } catch (e) {
      print("Login error: $e");
      return "An error occurred";
    }
  }

  /// Get current user name
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_name");
  }

  /// Get current user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_email");
  }

  /// Get current token (user id)
  static Future<String?> getToken() async {
    return await _storage.read(key: "token");
  }

  /// Logout
  static Future<void> logout() async {
    await _storage.delete(key: "token");
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
