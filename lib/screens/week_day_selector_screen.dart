import 'package:flutter/material.dart';
import '../services/program_exercise_service.dart';
import 'exercise_preview_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

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
  int highestUnlockedWeek = 1;

  // 🔑 Progress lookup
  Map<int, Set<int>> completedDaysByWeek = {};

  Map<String, dynamic>? programInfo;

  @override
  void initState() {
    super.initState();
    loadProgramStructure();
  }

  Future<void> loadProgramStructure() async {
    try {
      // 1️⃣ Program info
      final program = await supabase
          .from('fitness_programs')
          .select('name, description, image_url, weeks')
          .eq('id', widget.programId)
          .single();

      programInfo = program;

      final totalWeeks = program['weeks'] as int;
      weeks = List.generate(totalWeeks, (i) => i + 1);

      // 2️⃣ Program exercises (week 1 template)
      final data = await supabase
          .from('program_exercises')
          .select('week_number, day_number')
          .eq('program_id', widget.programId);

      rows = List<Map<String, dynamic>>.from(data);

      // 3️⃣ Load progress logs
      final userId = supabase.auth.currentUser!.id;

      final progressLogs = await supabase
          .from('progress_logs')
          .select('week_number, day_number')
          .eq('program_id', widget.programId)
          .eq('user_id', userId);

      completedDaysByWeek.clear();
      for (final p in progressLogs) {
        final w = p['week_number'] as int;
        final d = p['day_number'] as int;
        completedDaysByWeek.putIfAbsent(w, () => <int>{}).add(d);
      }

      highestUnlockedWeek =
          _computeHighestUnlockedWeek(totalWeeks);

      selectedWeek = 1;
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
      if (r['week_number'] == 1) {
        daySet.add(r['day_number']);
      }
    }
    daysForSelectedWeek = daySet.toList()..sort();
  }

  int _computeHighestUnlockedWeek(int totalWeeks) {
    final requiredDays = rows
        .where((r) => r['week_number'] == 1)
        .map((r) => r['day_number'] as int)
        .toSet();

    int unlocked = 1;
    for (int week = 1; week <= totalWeeks; week++) {
      final completed = completedDaysByWeek[week] ?? {};
      final isComplete =
      requiredDays.every((d) => completed.contains(d));
      if (isComplete) unlocked = week + 1;
      else break;
    }
    return unlocked.clamp(1, totalWeeks);
  }

  bool isDayLocked(int day) {
    if (selectedWeek > highestUnlockedWeek) return true;
    if (day == 1) return false;
    final completedDays =
        completedDaysByWeek[selectedWeek] ?? <int>{};
    return !completedDays.contains(day - 1);
  }

  bool isDayCompleted(int day) {
    return completedDaysByWeek[selectedWeek]?.contains(day) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (programInfo == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          /// 🔥 HEADER IMAGE WITH NAME + DESCRIPTION
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  programInfo!['image_url'] != null
                      ? Image.network(
                    programInfo!['image_url'],
                    fit: BoxFit.cover,
                  )
                      : Container(color: Colors.black12),

                  // Dark gradient for readability
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),

                  // Name + description text
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          programInfo!['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          programInfo!['description'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70, // ✅ lighter color
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  "Select Week",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 🗓️ Week grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: weeks.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                  ),
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    final locked = week > highestUnlockedWeek;

                    return GestureDetector(
                      onTap: locked
                          ? null
                          : () {
                        setState(() {
                          selectedWeek = week;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: locked
                              ? Colors.grey.shade400
                              : week == selectedWeek
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            "Week $week",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: locked
                                  ? Colors.white70
                                  : week == selectedWeek
                                  ? Colors.white
                                  : Colors.black,
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

                // 🏋️ Day cards
                ...daysForSelectedWeek.map((day) {
                  final locked = isDayLocked(day);
                  final completed = isDayCompleted(day);

                  return Card(
                    color: locked
                        ? Colors.grey.shade300
                        : completed
                        ? Colors.green.shade100
                        : null,
                    child: ListTile(
                      title: Text("Workout Day $day"),
                      trailing: completed
                          ? const Icon(Icons.check_circle,
                          color: Colors.green)
                          : locked
                          ? const Icon(Icons.lock)
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: locked
                          ? null
                          : () async {
                        final exercises =
                        await ProgramExerciseService
                            .fetchExercisesForDay(
                          programId: widget.programId,
                          weekNumber: selectedWeek,
                          dayNumber: day,
                        );

                        if (!mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExercisePreviewScreen(
                              exercises: exercises,
                              restSeconds: 60,
                              programId: widget.programId,
                              weekNumber: selectedWeek,
                              dayNumber: day,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
