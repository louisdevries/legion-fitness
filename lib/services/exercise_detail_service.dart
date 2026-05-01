import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program_exercise_details.dart';

final supabase = Supabase.instance.client;

class ProgramExerciseDetailService {
  static Future<List<ProgramExerciseDetail>> fetchDetailsForExercise(
      int programExerciseId) async {
    final data = await supabase
        .from('program_exercise_details')
        .select()
        .eq('program_exercise_id', programExerciseId);

    return List<Map<String, dynamic>>.from(data)
        .map((map) => ProgramExerciseDetail.fromMap(map))
        .toList();
  }

  /// Fetches the exercise name and media for a superset partner.
  static Future<Map<String, dynamic>?> fetchSupersetPartner(
      int exerciseId) async {
    final data = await supabase
        .from('exercises')
        .select('id, name, media_url, coaching_cues')
        .eq('id', exerciseId)
        .maybeSingle();

    return data;
  }
}