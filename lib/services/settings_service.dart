import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class SettingsService {
  static const _darkModeKey = 'theme_mode';
  static const _restSecondsKey = 'rest_seconds';

  /// -------- THEME --------

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_darkModeKey) ?? 'system';

    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString(_darkModeKey, value);
  }

  /// -------- REST TIMER --------

  static Future<int> getRestSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_restSecondsKey) ?? 60;
  }

  static Future<void> setRestSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_restSecondsKey, seconds);
    AppSettings.restTimerSeconds.value = seconds;
  }
}
