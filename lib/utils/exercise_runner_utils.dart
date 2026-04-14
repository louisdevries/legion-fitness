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

  static String getName(Map<String, dynamic> exercise) =>
      exercise['name'] as String? ?? 'Exercise';

  static String? getMediaUrl(Map<String, dynamic> exercise) =>
      exercise['media_url'] as String?;

  static String getCoachingCues(Map<String, dynamic> exercise) =>
      exercise['coaching_cues'] as String? ?? '';
}