import 'food.dart';

class MealLog {
  static const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  final String id; // = meal_logs.client_id
  final String mealType;
  final double grams;
  final DateTime loggedAt;
  final Food food;
  final bool synced;

  MealLog({
    required this.id,
    required this.mealType,
    required this.grams,
    required this.loggedAt,
    required this.food,
    this.synced = true,
  });

  double get kcal => food.kcal100g * grams / 100;
  double get protein => (food.protein100g ?? 0) * grams / 100;
  double get carbs => (food.carbs100g ?? 0) * grams / 100;
  double get fat => (food.fat100g ?? 0) * grams / 100;
}
