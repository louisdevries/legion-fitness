import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/progress_log.dart';
import 'dart:developer' as developer;

final supabase = Supabase.instance.client;

class ProgressService {
  static Future<List<ProgressLog>> getUserProgress() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('progress_logs')
        .select()
        .eq('user_id', user.id)
        .order('date');

    return (response as List)
        .map((e) => ProgressLog.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ProgressLog>> getUserCompletions() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('exercise_completions')
        .select()
        .eq('user_id', user.id)
        .order('completed_at');

    return (response as List).map((e) {
      final m = e as Map<String, dynamic>;
      return ProgressLog(
        id: (m['id'] as num).toInt(),
        exerciseId: (m['exercise_id'] as num).toInt(),
        programId: (m['program_id'] as num).toInt(),
        weekNumber: (m['week_number'] as num).toInt(),
        dayNumber: (m['day_number'] as num).toInt(),
        repsCompleted: (m['reps_completed'] as num?)?.toInt() ?? 0,
        weightUsedKg: null, // exercise_completions doesn't track weight
        date: DateTime.parse(m['completed_at'] as String),
        userId: m['user_id'] as String,
      );
    }).toList();
  }

  static Future<bool> isDayCompleted({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final exercises = await supabase
        .from('program_exercises')
        .select('id')
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber);

    final totalExercises = (exercises as List).length;

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

    try {
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
    } catch (e, stack) {
      developer.log('Error inserting progress log', error: e, stackTrace: stack);
    }
  }

  // per-set logging with setIndex and actual reps
  static Future<void> logExerciseCompletion({
    required int programId,
    required int exerciseId,
    required int weekNumber,
    required int dayNumber,
    required int setIndex,
    required int repsCompleted,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      developer.log('⛔ logExerciseCompletion: no user logged in, cannot log completion.');
      return;
    }

    try {
      final result = await supabase.from('exercise_completions').upsert(
        {
          'user_id': user.id,
          'program_id': programId,
          'exercise_id': exerciseId,
          'week_number': weekNumber,
          'day_number': dayNumber,
          'set_index': setIndex,
          'reps_completed': repsCompleted,
          'completed_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,program_id,exercise_id,week_number,day_number,set_index',
      ).select();
      developer.log('✅ logExerciseCompletion: upsert returned ${result.length} row(s) for exerciseId=$exerciseId setIndex=$setIndex');
    } catch (e, stack) {
      developer.log('⛔ logExerciseCompletion: upsert FAILED for exerciseId=$exerciseId setIndex=$setIndex: $e', error: e, stackTrace: stack);
      rethrow;
    }
  }
}