import 'package:flutter/material.dart';
import '../services/program_exercise_service.dart';
import 'exercise_preview_screen.dart';
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

  Map<String, dynamic>? programInfo;

  @override
  void initState() {
    super.initState();
    loadProgramStructure();
  }

  Future<void> loadProgramStructure() async {
    try {
      final program = await supabase
          .from('fitness_programs')
          .select('name, description, image_url, weeks')
          .eq('id', widget.programId)
          .single();

      programInfo = program;

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
      if (r['week_number'] == selectedWeek) {
        daySet.add(r['day_number']);
      }
    }
    daysForSelectedWeek = daySet.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (programInfo == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [

              // 🧱 COLLAPSING HEADER
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.black,
                automaticallyImplyLeading: false,

                // ✅ CUSTOM BACK BUTTON (ALWAYS VISIBLE)
                leading: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),

                title: Text(programInfo!['name']),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        programInfo!['image_url'],
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              programInfo!['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              programInfo!['description'] ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 📦 CONTENT
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    const Text(
                      "Select Week",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // 🗓️ WEEK GRID
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: weeks.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                      ),
                      itemBuilder: (context, index) {
                        final week = weeks[index];
                        final isSelected = week == selectedWeek;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedWeek = week;
                              computeDays();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isSelected
                                  ? [const BoxShadow(color: Colors.black26, blurRadius: 6)]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                "Week $week",
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "Select Workout",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // 🏋️ DAY CARDS
                    ...daysForSelectedWeek.map((day) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            title: Text(
                              "Workout Day $day",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text("Tap to start workout"),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: isLoading
                                ? null
                                : () async {
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
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
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
