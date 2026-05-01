import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/program_exercise_service.dart';
import '../services/workout_engine_service.dart';
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

  Map<int, Set<int>> completedDaysByWeek = {};
  Map<String, dynamic>? programInfo;

  bool isActiveProgram = false;

  // ENGINE DATA
  Map<String, int> requiredSetsByDay = {};
  Map<String, int> loggedSetsByDay = {};

  @override
  void initState() {
    super.initState();
    loadProgramStructure();
    _loadActiveProgram();
  }

  Future<void> _loadActiveProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('active_program_id');
    setState(() => isActiveProgram = activeId == widget.programId);
  }

  Future<void> _activateProgram() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_program_id', widget.programId);
    await prefs.setInt('active_week_number', selectedWeek);

    setState(() => isActiveProgram = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Program activated')),
    );
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

      rows = List<Map<String, dynamic>>.from(
        await supabase
            .from('program_exercises')
            .select('week_number, day_number')
            .eq('program_id', widget.programId),
      );

      final userId = supabase.auth.currentUser!.id;

      // -----------------------------
      // STEP 1: REQUIRED EXERCISES PER DAY
      // Each exercise counts as 1 unit — a day is done when all
      // exercises have at least one completion logged.
      // -----------------------------
      final programExercises = await supabase
          .from('program_exercises')
          .select('week_number, day_number, exercise_id')
          .eq('program_id', widget.programId);

      // Count how many distinct exercises exist per day
      final Map<String, Set<int>> requiredExercisesByDay = {};
      for (final pe in programExercises) {
        final key = '${pe['week_number']}-${pe['day_number']}';
        requiredExercisesByDay.putIfAbsent(key, () => <int>{});
        requiredExercisesByDay[key]!.add(pe['exercise_id'] as int);
      }

      // -----------------------------
      // STEP 2: COMPLETED EXERCISES PER DAY
      // From exercise_completions — deduplicate by exercise_id
      // so multiple sets don't inflate the count.
      // -----------------------------
      final completionLogs = await supabase
          .from('exercise_completions')
          .select('week_number, day_number, exercise_id')
          .eq('program_id', widget.programId)
          .eq('user_id', userId);

      final Map<String, Set<int>> completedExercisesByDay = {};
      for (final log in completionLogs) {
        final key = '${log['week_number']}-${log['day_number']}';
        completedExercisesByDay.putIfAbsent(key, () => <int>{});
        completedExercisesByDay[key]!.add(log['exercise_id'] as int);
      }

      // -----------------------------
      // STEP 3: MARK DAY COMPLETE WHEN ALL EXERCISES DONE
      // -----------------------------
      completedDaysByWeek.clear();

      requiredExercisesByDay.forEach((key, required) {
      final completed = completedExercisesByDay[key] ?? <int>{};
      if (completed.length >= required.length) {
      final parts = key.split('-');
      final week = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      completedDaysByWeek.putIfAbsent(week, () => {}).add(day);
      }
      });

      highestUnlockedWeek = _computeHighestUnlockedWeek(totalWeeks);
      selectedWeek = 1;
      computeDays();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void computeDays() {
    daysForSelectedWeek = rows
        .where((r) => r['week_number'] == selectedWeek)
        .map((r) => r['day_number'] as int)
        .toSet()
        .toList()
      ..sort();
  }

  int _computeHighestUnlockedWeek(int totalWeeks) {
    int unlocked = 1;

    for (int week = 1; week <= totalWeeks; week++) {
      final weekDays = rows
          .where((r) => r['week_number'] == week)
          .map((r) => r['day_number'] as int)
          .toSet();

      final completed = completedDaysByWeek[week] ?? {};

      if (weekDays.every(completed.contains)) {
        unlocked = week + 1;
      } else {
        break;
      }
    }

    return unlocked.clamp(1, totalWeeks);
  }

  bool isDayLocked(int day) {
    if (selectedWeek > highestUnlockedWeek) return true;
    if (day == 1) return false;
    return !(completedDaysByWeek[selectedWeek]?.contains(day - 1) ?? false);
  }

  bool isDayCompleted(int day) =>
      completedDaysByWeek[selectedWeek]?.contains(day) ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (programInfo == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
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
                  if (programInfo!['image_url'] != null)
                    Image.network(
                      programInfo!['image_url'],
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: Colors.black),

                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
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
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (programInfo!['description'] != null)
                          Text(
                            programInfo!['description'],
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
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
                ElevatedButton.icon(
                  icon: Icon(isActiveProgram
                      ? Icons.check_circle
                      : Icons.play_arrow),
                  label: Text(
                      isActiveProgram ? 'Program Active' : 'Start Program'),
                  onPressed: isActiveProgram ? null : _activateProgram,
                ),

                const SizedBox(height: 24),

                Text("Select Week",
                    style: theme.textTheme.titleLarge),

                const SizedBox(height: 12),

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
                  itemBuilder: (_, i) {
                    final week = weeks[i];
                    final locked = week > highestUnlockedWeek;
                    final selected = week == selectedWeek;

                    return GestureDetector(
                      onTap: locked
                          ? null
                          : () => setState(() => selectedWeek = week),
                      child: Container(
                        decoration: BoxDecoration(
                          color: locked
                              ? cs.surfaceVariant
                              : selected
                              ? cs.primaryContainer
                              : cs.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text("Week $week"),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text("Select Workout",
                    style: theme.textTheme.titleLarge),

                const SizedBox(height: 12),

                ...daysForSelectedWeek.map((day) {
                  final locked = isDayLocked(day);
                  final completed = isDayCompleted(day);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: locked
                          ? cs.surfaceVariant
                          : completed
                          ? cs.secondaryContainer
                          : cs.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      title: Text("Workout Day $day"),
                      trailing: completed
                          ? const Icon(Icons.check_circle)
                          : locked
                          ? const Icon(Icons.lock)
                          : const Icon(Icons.arrow_forward_ios),
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