import 'package:flutter/material.dart';

class ExerciseCategoryUtils {
  static String resolveCategory(Map<String, dynamic> exercise) {
    final raw = (exercise['category'] ?? exercise['category_name'] ?? 'main')
        .toString()
        .toLowerCase()
        .trim();

    if (raw.contains('warm')) return 'warmup';
    if (raw.contains('cool')) return 'cooldown';
    if (raw.contains('main')) return 'main';

    return 'main';
  }

  static String getLabel(String category) {
    switch (category) {
      case 'warmup':
        return '🔥 Warm-up';
      case 'cooldown':
        return '❄️ Cool-down';
      default:
        return '💪 Main Workout';
    }
  }

  static Color getColor(String category) {
    switch (category) {
      case 'warmup':
        return Colors.orange;
      case 'cooldown':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }
}