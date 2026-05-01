import 'dart:math';

class ExerciseRunnerUtils {
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

  static int getMinQuantity(Map<String, dynamic> exercise) =>
      exercise['min_quantity'] as int? ?? 0;

  static int getMaxQuantity(Map<String, dynamic> exercise) =>
      exercise['max_quantity'] as int? ?? getMinQuantity(exercise);

  static int getQuantity(Map<String, dynamic> exercise) {
    final minQ = getMinQuantity(exercise);
    final maxQ = getMaxQuantity(exercise);
    return max(1, ((minQ + maxQ) / 2).round());
  }

  static String getQuantityDisplay(Map<String, dynamic> exercise) {
    final minQ = getMinQuantity(exercise);
    final maxQ = getMaxQuantity(exercise);
    return minQ == maxQ ? '$minQ' : '$minQ-$maxQ';
  }

  static bool isTimedExercise(Map<String, dynamic> exercise) {
    final t = (exercise['duration_type'] ?? '').toString().toLowerCase();
    return t.contains('sec');
  }

  static String getName(Map<String, dynamic> exercise) {
    final name = exercise['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return 'Exercise';
  }

  /// Returns empty string (never null) so callers can safely do mediaUrl.isEmpty
  static String getMediaUrl(Map<String, dynamic> exercise) {
    final url = exercise['media_url'];
    if (url is String && url.trim().isNotEmpty) return url.trim();
    return '';
  }

  static String getCoachingCues(Map<String, dynamic> exercise) =>
      exercise['coaching_cues'] as String? ?? '';
}