/// Distributes a min–max quantity range evenly across a number of sets,
/// e.g. 3 sets of 8–12 becomes [8, 10, 12] instead of repeating the
/// minimum for every set.
class RepSchemeUtils {
  static List<int> evenlySpaced({
    required int sets,
    required int minQuantity,
    required int maxQuantity,
  }) {
    if (sets <= 1 || maxQuantity <= minQuantity) {
      return List.filled(sets, minQuantity);
    }
    return List.generate(sets, (i) {
      final t = i / (sets - 1);
      return (minQuantity + (maxQuantity - minQuantity) * t).round();
    });
  }
}
