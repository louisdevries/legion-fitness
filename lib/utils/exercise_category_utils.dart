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

  /// Badge fill per section. All light enough for dark ink text.
  static Color getColor(String category) {
    switch (category) {
      case 'warmup':
        return const Color(0xFFE8B84E); // amber
      case 'cooldown':
        return const Color(0xFF7FD1C2); // soft teal
      default:
        return const Color(0xFFC8F135); // lime
    }
  }
}