import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/progress_log.dart';

final supabase = Supabase.instance.client;

class ProgressService {
  /// Fetch all progress logs for a user for a program
  static Future<List<ProgressLog>> getUserProgress(int programId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('progress_logs')
        .select()
        .eq('user_id', user.id)
        .eq('program_id', programId);

    if (response is List) {
      return response
          .map((e) => ProgressLog.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Check if a specific day is completed
  static Future<bool> isDayCompleted({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    // Total exercises for this day
    final exercises = await supabase
        .from('program_exercises')
        .select('id')
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber);

    final totalExercises = (exercises as List).length;

    // Logged exercises
    final logs = await supabase
        .from('progress_logs')
        .select('id')
        .eq('user_id', user.id)
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber);

    final completedCount = (logs as List).length;

    return completedCount >= totalExercises;
  }

  /// Log exercise completion
  static Future<void> logExercise({
    required int programId,
    required int exerciseId,
    required int weekNumber,
    required int dayNumber,
    required int repsCompleted,
    double? weightUsedKg,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('progress_logs').insert({
      'user_id': user.id,
      'program_id': programId,
      'exercise_id': exerciseId,
      'week_number': weekNumber,
      'day_number': dayNumber,
      'reps_completed': repsCompleted,
      'weight_used_kg': weightUsedKg,
      'date': DateTime.now().toIso8601String(),
    });
  }
}
