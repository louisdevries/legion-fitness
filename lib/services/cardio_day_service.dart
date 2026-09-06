import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

/// Service for cardio day metadata and completions.
///
/// Cardio days are days in a program where the user is expected to do
/// an outdoor run (or equivalent), rather than a strength session.
/// They're marked complete either automatically when a qualifying run
/// is saved, or manually via the "Mark done" button.
class CardioDayService {
  static final _supabase = Supabase.instance.client;

  // ===================================================================
  // FETCH
  // ===================================================================

  /// Returns the map of "week-day" → ProgramDay for the given program,
  /// covering all weeks. Used by the week/day selector to know which
  /// days are cardio vs workout.
  static Future<Map<String, ProgramDay>> fetchProgramDays(int programId) async {
    try {
      final rows = await _supabase
          .from('program_days')
          .select()
          .eq('program_id', programId);

      final map = <String, ProgramDay>{};
      for (final r in rows as List) {
        final pd = ProgramDay.fromMap(r as Map<String, dynamic>);
        map['${pd.weekNumber}-${pd.dayNumber}'] = pd;
      }
      return map;
    } catch (e) {
      developer.log('fetchProgramDays error: $e');
      return {};
    }
  }

  /// Returns the ProgramDay for a specific week/day, or null.
  static Future<ProgramDay?> fetchDay(
      int programId, int weekNumber, int dayNumber) async {
    try {
      final row = await _supabase
          .from('program_days')
          .select()
          .eq('program_id', programId)
          .eq('week_number', weekNumber)
          .eq('day_number', dayNumber)
          .maybeSingle();
      if (row == null) return null;
      return ProgramDay.fromMap(row);
    } catch (e) {
      developer.log('fetchDay error: $e');
      return null;
    }
  }

  /// Returns the set of "week-day" keys that this user has completed
  /// via cardio for the given program.
  static Future<Set<String>> fetchCompletedCardioKeys(int programId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};

    try {
      final rows = await _supabase
          .from('cardio_day_completions')
          .select('week_number, day_number')
          .eq('user_id', user.id)
          .eq('program_id', programId);

      return {
        for (final r in rows as List) '${r['week_number']}-${r['day_number']}'
      };
    } catch (e) {
      developer.log('fetchCompletedCardioKeys error: $e');
      return {};
    }
  }

  // ===================================================================
  // MARK COMPLETE
  // ===================================================================

  /// Manual completion — user tapped "Mark done" on the cardio day screen.
  static Future<bool> markManualComplete({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    return _insertCompletion(
      programId: programId,
      weekNumber: weekNumber,
      dayNumber: dayNumber,
      source: 'manual',
      runId: null,
    );
  }

  /// Auto-complete on run save. Finds the earliest incomplete cardio day
  /// for the user's active program that this run's duration satisfies,
  /// and marks it complete. Returns true if a day was marked (so the UI
  /// can show a confirmation).
  ///
  /// Call this from RunService.saveRun (or wherever runs get persisted)
  /// AFTER the run is written to outdoor_runs.
  static Future<CardioAutoComplete?> tryAutoCompleteFromRun({
    required int programId,
    required int? runId,
    required int runDurationSeconds,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      // Load all cardio days for the program.
      final allCardio = await _supabase
          .from('program_days')
          .select()
          .eq('program_id', programId)
          .eq('day_type', 'cardio')
          .order('week_number', ascending: true)
          .order('day_number', ascending: true);

      // Load what the user's already done.
      final done = await fetchCompletedCardioKeys(programId);

      // Find the earliest cardio day that: isn't done, and this run
      // meets the threshold for.
      for (final r in allCardio as List) {
        final pd = ProgramDay.fromMap(r as Map<String, dynamic>);
        final key = '${pd.weekNumber}-${pd.dayNumber}';
        if (done.contains(key)) continue;

        final threshold = pd.minDurationSeconds ?? 900; // default 15 min
        if (runDurationSeconds < threshold) continue;

        // This run qualifies. Mark the day complete.
        final ok = await _insertCompletion(
          programId: programId,
          weekNumber: pd.weekNumber,
          dayNumber: pd.dayNumber,
          source: 'run',
          runId: runId,
        );
        if (ok) {
          return CardioAutoComplete(
            programId: programId,
            weekNumber: pd.weekNumber,
            dayNumber: pd.dayNumber,
            title: pd.title ?? 'Cardio day',
          );
        }
      }
      return null;
    } catch (e) {
      developer.log('tryAutoCompleteFromRun error: $e');
      return null;
    }
  }

  // ===================================================================
  // INTERNAL
  // ===================================================================

  static Future<bool> _insertCompletion({
    required int programId,
    required int weekNumber,
    required int dayNumber,
    required String source,
    required int? runId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      // Upsert with ignoreDuplicates handles the case where a day is
      // already complete (unique constraint prevents doubles).
      final result = await _supabase.from('cardio_day_completions').upsert({
        'user_id': user.id,
        'program_id': programId,
        'week_number': weekNumber,
        'day_number': dayNumber,
        'source': source,
        'run_id': runId,
      }, onConflict: 'user_id,program_id,week_number,day_number', ignoreDuplicates: true).select();

      return (result as List).isNotEmpty;
    } catch (e) {
      developer.log('cardio completion insert error: $e');
      return false;
    }
  }
}

// =====================================================================
// MODELS
// =====================================================================

class ProgramDay {
  final int id;
  final int programId;
  final int weekNumber;
  final int dayNumber;
  final String dayType;
  final String? title;
  final String? notes;
  final int? minDurationSeconds;

  ProgramDay({
    required this.id,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    required this.dayType,
    required this.title,
    required this.notes,
    required this.minDurationSeconds,
  });

  factory ProgramDay.fromMap(Map<String, dynamic> m) {
    return ProgramDay(
      id: (m['id'] as num).toInt(),
      programId: (m['program_id'] as num).toInt(),
      weekNumber: (m['week_number'] as num).toInt(),
      dayNumber: (m['day_number'] as num).toInt(),
      dayType: m['day_type'] as String,
      title: m['title'] as String?,
      notes: m['notes'] as String?,
      minDurationSeconds: (m['min_duration_seconds'] as num?)?.toInt(),
    );
  }

  bool get isCardio => dayType == 'cardio';
  bool get isWorkout => dayType == 'workout';
}

class CardioAutoComplete {
  final int programId;
  final int weekNumber;
  final int dayNumber;
  final String title;

  CardioAutoComplete({
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    required this.title,
  });
}