import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionTargets {
  final int kcal;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;

  const NutritionTargets({
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  factory NutritionTargets.fromMap(Map<String, dynamic> m) => NutritionTargets(
        kcal: (m['kcal'] as num).toInt(),
        proteinG: (m['protein_g'] as num?)?.toInt(),
        carbsG: (m['carbs_g'] as num?)?.toInt(),
        fatG: (m['fat_g'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'kcal': kcal,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };
}

enum Sex { male, female }

enum ActivityLevel {
  sedentary('Sedentary', 'Desk job, little exercise', 1.2),
  light('Lightly active', 'Exercise 1–3 days a week', 1.375),
  moderate('Moderately active', 'Exercise 3–5 days a week', 1.55),
  very('Very active', 'Hard exercise 6–7 days a week', 1.725),
  extra('Extra active', 'Physical job plus training', 1.9);

  final String label;
  final String description;
  final double factor;
  const ActivityLevel(this.label, this.description, this.factor);
}

enum Goal {
  lose('Lose weight', -500),
  maintain('Maintain', 0),
  gain('Build muscle', 300);

  final String label;
  final int kcalAdjustment;
  const Goal(this.label, this.kcalAdjustment);
}

/// Body stats from the health profile and the latest weight log.
class BodyStats {
  final DateTime? dateOfBirth;
  final double? heightCm;
  final double? weightKg;
  const BodyStats({this.dateOfBirth, this.heightCm, this.weightKg});

  bool get isComplete =>
      dateOfBirth != null && heightCm != null && weightKg != null;

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
}

class NutritionTargetsService {
  static final _client = Supabase.instance.client;
  static const _cacheKey = 'nutrition_targets';

  /// The user's targets, or null if never set. Falls back to the copy
  /// cached on this device when offline.
  static Future<NutritionTargets?> getTargets() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    try {
      final row = await _client
          .from('nutrition_targets')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) {
        await prefs.remove(_cacheKey);
        return null;
      }
      final targets = NutritionTargets.fromMap(row);
      await prefs.setString(_cacheKey, jsonEncode(targets.toMap()));
      return targets;
    } catch (_) {
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;
      return NutritionTargets.fromMap(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  static Future<void> saveTargets(NutritionTargets targets) async {
    await _client.from('nutrition_targets').upsert({
      ...targets.toMap(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(targets.toMap()));
  }

  static Future<BodyStats> getBodyStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return const BodyStats();

    final profile = await _client
        .from('health_profiles')
        .select('date_of_birth, height_cm')
        .eq('user_id', user.id)
        .maybeSingle();
    final weight = await _client
        .from('weight_logs')
        .select('weight_kg')
        .eq('user_id', user.id)
        .order('logged_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final dob = profile?['date_of_birth'] as String?;
    return BodyStats(
      dateOfBirth: dob == null ? null : DateTime.parse(dob),
      heightCm: (profile?['height_cm'] as num?)?.toDouble(),
      weightKg: (weight?['weight_kg'] as num?)?.toDouble(),
    );
  }

  /// Mifflin-St Jeor BMR × activity, adjusted for the goal. Protein at
  /// 2 g/kg, fat at 25% of calories, carbs make up the rest.
  static NutritionTargets calculate({
    required BodyStats stats,
    required Sex sex,
    required ActivityLevel activity,
    required Goal goal,
  }) {
    final w = stats.weightKg!;
    final bmr = 10 * w +
        6.25 * stats.heightCm! -
        5 * stats.age! +
        (sex == Sex.male ? 5 : -161);

    final floor = sex == Sex.male ? 1500 : 1200;
    final kcal = ((bmr * activity.factor) + goal.kcalAdjustment)
        .round()
        .clamp(floor, 6000);

    final protein = (2.0 * w).round();
    final fat = (kcal * 0.25 / 9).round();
    final carbs = ((kcal - protein * 4 - fat * 9) / 4).round().clamp(0, 2000);

    return NutritionTargets(
      kcal: kcal,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
    );
  }
}
