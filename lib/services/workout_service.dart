import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class WorkoutService {
  static Future<List<int>> getWeeksForProgram(int programId) async {
    final data = await supabase
        .from('program_exercises')
        .select('week_number')
        .eq('program_id', programId);

    final weeks = (data as List)
        .map((e) => e['week_number'] as int)
        .toSet()
        .toList();

    weeks.sort();
    return weeks;
  }

  static Future<List<int>> getDaysForWeek(int programId, int week) async {
    final data = await supabase
        .from('program_exercises')
        .select('day_number')
        .eq('program_id', programId)
        .eq('week_number', week);

    final days = (data as List)
        .map((e) => e['day_number'] as int)
        .toSet()
        .toList();

    days.sort();
    return days;
  }

  static Future<List<Map<String, dynamic>>> getWorkout(
      int programId,
      int week,
      int day,
      ) async {
    final data = await supabase
        .from('program_exercises')
        .select('''
          id,
          program_exercise_details (
            *,
            exercises (*)
          )
        ''')
        .eq('program_id', programId)
        .eq('week_number', week)
        .eq('day_number', day)
        .order('id');

    return (data as List).cast<Map<String, dynamic>>();
  }
}
