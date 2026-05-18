import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/programs.dart';

final supabase = Supabase.instance.client;

Future<List<Program>> fetchPrograms() async {
  try {
    final userId = supabase.auth.currentUser?.id;

    // Fetch public programs (no user_id) plus this user's premium programs.
    // Guests only see public programs.
    final query = userId != null
        ? supabase
            .from('fitness_programs')
            .select()
            .or('user_id.is.null,user_id.eq.$userId')
            .order('id', ascending: true)
        : supabase
            .from('fitness_programs')
            .select()
            .isFilter('user_id', null)
            .order('id', ascending: true);

    final data = await query as List<dynamic>;
    return data.map((p) => Program.fromMap(p as Map<String, dynamic>)).toList();
  } catch (e, st) {
    print("Error fetching programs: $e");
    print(st);
    return [];
  }
}
