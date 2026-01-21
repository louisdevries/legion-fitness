import 'package:flutter/material.dart';
import '../services/program_exercise_service.dart';
import 'exercise_runner_screen.dart';

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

    setState(() => isLoading = false);
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
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Select Workout")),
      body: Padding(
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
                  onPressed: () async {
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
                        builder: (_) => ExerciseRunnerScreen(
                          exercises: exercises,
                          restSeconds: 60,
                        ),

                      ),
                    );
                  },
                  child: Text("Day $day"),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
