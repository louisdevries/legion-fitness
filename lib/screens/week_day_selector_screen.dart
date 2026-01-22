import 'package:flutter/material.dart';
import '../services/program_exercise_service.dart';
import 'exercise_preview_screen.dart';
import 'exercise_runner_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeekDaySelectorScreen extends StatefulWidget {
  final int programId;
  const WeekDaySelectorScreen({super.key, required this.programId});

  @override
  State<WeekDaySelectorScreen> createState() => _WeekDaySelectorScreenState();
}

class _WeekDaySelectorScreenState extends State<WeekDaySelectorScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> rows = [];
  List<int> weeks = [];
  List<int> daysForSelectedWeek = [];
  int selectedWeek = 1;

  @override
  void initState() {
    super.initState();
    loadProgramStructure();
  }

  Future<void> loadProgramStructure() async {
    try {
      final program = await supabase
          .from('fitness_programs')
          .select('weeks')
          .eq('id', widget.programId)
          .single();

      final totalWeeks = program['weeks'] as int;
      weeks = List.generate(totalWeeks, (i) => i + 1);

      final data = await supabase
          .from('program_exercises')
          .select('week_number, day_number')
          .eq('program_id', widget.programId);

      rows = List<Map<String, dynamic>>.from(data);

      selectedWeek = weeks.first;
      computeDays();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load program: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void computeDays() {
    final daySet = <int>{};
    for (final r in rows) {
      if (r['week_number'] == selectedWeek) daySet.add(r['day_number']);
    }
    daysForSelectedWeek = daySet.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Workout")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Week", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: weeks.length,
                    itemBuilder: (context, index) {
                      final week = weeks[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text("Week $week"),
                          selected: week == selectedWeek,
                          onSelected: (_) {
                            setState(() {
                              selectedWeek = week;
                              computeDays();
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Text("Day", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: daysForSelectedWeek.map((day) {
                    return ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        setState(() => isLoading = true);
                        try {
                          final exercises = await ProgramExerciseService.fetchExercisesForDay(
                            programId: widget.programId,
                            weekNumber: selectedWeek,
                            dayNumber: day,
                          );

                          if (!mounted) return;

                          if (exercises.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No exercises found for this day.')),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExercisePreviewScreen(
                                exercises: exercises,
                                restSeconds: 60,
                              ),
                            ),
                          );

                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to load exercises: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => isLoading = false);
                        }
                      },
                      child: Text("Day $day"),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
