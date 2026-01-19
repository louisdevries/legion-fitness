import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/programs.dart';

final supabase = Supabase.instance.client;

Future<List<Program>> fetchPrograms() async {
  try {
    // fetch all rows
    final data = await supabase
        .from('fitness_programs')
        .select()
        .order('id', ascending: true) as List<dynamic>;

    // map to Program objects
    return data.map((p) => Program.fromMap(p as Map<String, dynamic>)).toList();
  } catch (e, st) {
    print("Error fetching programs: $e");
    print(st);
    return [];
  }
}
