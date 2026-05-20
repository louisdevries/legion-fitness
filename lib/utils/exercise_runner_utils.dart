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

  /// Display the prescribed quantity in human-readable form.
  /// - "until failure" exercises: show "until failure"
  /// - timed exercises: just the number (the unit is shown elsewhere)
  /// - rep-based: just the number
  /// - ranges (min != max): "8-12"
  static String getQuantityDisplay(
      Map<String, dynamic> exercise, {
        int? currentSet,
      }) {
    final setQuantities = exercise['set_quantities'];
    if (setQuantities is List &&
        setQuantities.isNotEmpty &&
        currentSet != null &&
        currentSet <= setQuantities.length) {
      final v = (setQuantities[currentSet - 1] as num).toInt();
      if (v > 0) return '$v';
    }
    if (isUntilFailure(exercise)) return 'until failure';
    final minQ = getMinQuantity(exercise);
    final maxQ = getMaxQuantity(exercise);
    return minQ == maxQ ? '$minQ' : '$minQ-$maxQ';
  }
  /// True when this exercise's countdown should be a stopwatch (any
  /// duration type containing "second").
  static bool isTimedExercise(Map<String, dynamic> exercise) {
    final t = (exercise['duration_type'] ?? '').toString().toLowerCase();
    return t.contains('sec');
  }

  /// True when the exercise must be performed on each side separately
  /// (reps_each_side, seconds_each_side, etc).
  static bool isEachSide(Map<String, dynamic> exercise) {
    final t = (exercise['duration_type'] ?? '').toString().toLowerCase();
    return t.contains('side');
  }

  /// True when the exercise's rep target is "do as many as possible".
  /// Match anything containing the word "failure".
  static bool isUntilFailure(Map<String, dynamic> exercise) {
    final t = (exercise['duration_type'] ?? '').toString().toLowerCase();
    return t.contains('failure');
  }

  static String getName(Map<String, dynamic> exercise) {
    final name = exercise['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return 'Exercise';
  }

  static String getMediaUrl(Map<String, dynamic> exercise) {
    final url = exercise['media_url'];
    if (url is String && url.trim().isNotEmpty) return url.trim();
    return '';
  }

  static String getCoachingCues(Map<String, dynamic> exercise) =>
      exercise['coaching_cues'] as String? ?? '';
}