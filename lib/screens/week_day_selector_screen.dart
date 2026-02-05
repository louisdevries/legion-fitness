import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Progress lookup
  Map<int, Set<int>> completedDaysByWeek = {};

  Map<String, dynamic>? programInfo;

  /// 🔹 NEW: active state
  bool isActiveProgram = false;

  @override
  void initState() {
    super.initState();
    loadProgramStructure();
    _loadActiveProgram();
  }

  // ================= ACTIVE PROGRAM =================

  Future<void> _loadActiveProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('active_program_id');
    setState(() {
      isActiveProgram = activeId == widget.programId;
    });
  }

  Future<void> _activateProgram() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_program_id', widget.programId);
    await prefs.setInt('active_week_number', selectedWeek);

    setState(() {
      isActiveProgram = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Program activated')),
    );
  }

  // ================= RESET PROGRESS =================

  Future<void> _resetProgress() async {
    final userId = supabase.auth.currentUser!.id;

    await supabase
        .from('progress_logs')
        .delete()
        .eq('program_id', widget.programId)
        .eq('user_id', userId);

    completedDaysByWeek.clear();
    highestUnlockedWeek = 1;
    selectedWeek = 1;

    computeDays();

    if (mounted) {
      setState(() {});
    }
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restart Program?'),
        content: const Text(
          'This will clear all your workout progress for this program. '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _resetProgress();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // ================= LOAD DATA =================

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

      highestUnlockedWeek = _computeHighestUnlockedWeek(totalWeeks);
      selectedWeek = 1;
      computeDays();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load program: $e')));
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
      if (requiredDays.every((d) => completed.contains(d))) {
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
    final completed = completedDaysByWeek[selectedWeek] ?? {};
    return !completed.contains(day - 1);
  }

  bool isDayCompleted(int day) {
    return completedDaysByWeek[selectedWeek]?.contains(day) ?? false;
  }

  // ================= UI =================

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
          /// HEADER
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.restart_alt, color: Colors.white),
                onPressed: _confirmReset,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  programInfo!['image_url'] != null
                      ? Image.network(
                    programInfo!['image_url'],
                    fit: BoxFit.cover,
                  )
                      : Container(color: Colors.black12),

                  // Gradient overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),

                  // ✅ Program name & description (RESTORED)
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
                            color: Colors.white70,
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

          /// BODY
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                /// 🔹 NEW: Start Program button
                ElevatedButton.icon(
                  icon: Icon(isActiveProgram
                      ? Icons.check_circle
                      : Icons.play_arrow),
                  label: Text(
                      isActiveProgram ? 'Program Active' : 'Start Program'),
                  onPressed: isActiveProgram ? null : _activateProgram,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "Select Week",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
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
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    final locked = week > highestUnlockedWeek;

                    return GestureDetector(
                      onTap: locked
                          ? null
                          : () => setState(() => selectedWeek = week),
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
                          ? const Icon(Icons.check_circle, color: Colors.green)
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
