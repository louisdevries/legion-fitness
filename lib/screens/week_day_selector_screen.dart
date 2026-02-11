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

  Map<int, Set<int>> completedDaysByWeek = {};
  Map<String, dynamic>? programInfo;

  bool isActiveProgram = false;

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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Program activated')));
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

      final progressLogs = await supabase
          .from('progress_logs')
          .select('week_number, day_number')
          .eq('program_id', widget.programId)
          .eq('user_id', userId);

      completedDaysByWeek.clear();
      for (final p in progressLogs) {
        completedDaysByWeek
            .putIfAbsent(p['week_number'], () => {})
            .add(p['day_number']);
      }

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
    final requiredDays = rows
        .where((r) => r['week_number'] == 1)
        .map((r) => r['day_number'] as int)
        .toSet();

    int unlocked = 1;
    for (int week = 1; week <= totalWeeks; week++) {
      final completed = completedDaysByWeek[week] ?? {};
      if (requiredDays.every(completed.contains)) {
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
          /// HEADER
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
                  /// Background image
                  if (programInfo!['image_url'] != null)
                    Image.network(
                      programInfo!['image_url'],
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: Colors.black),

                  /// Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
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

                  /// ✅ PROGRAM TEXT (RESTORED)
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
                ElevatedButton.icon(
                  icon: Icon(isActiveProgram
                      ? Icons.check_circle
                      : Icons.play_arrow),
                  label:
                  Text(isActiveProgram ? 'Program Active' : 'Start Program'),
                  onPressed: isActiveProgram ? null : _activateProgram,
                ),

                const SizedBox(height: 24),

                Text("Select Week",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),

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

                    final bgColor = locked
                        ? cs.surfaceVariant
                        : selected
                        ? cs.primaryContainer
                        : cs.surface;

                    final textColor = locked
                        ? cs.onSurface.withOpacity(0.4)
                        : selected
                        ? cs.onPrimaryContainer
                        : cs.onSurface;

                    return GestureDetector(
                      onTap: locked
                          ? null
                          : () => setState(() => selectedWeek = week),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.onSurface.withOpacity(0.08),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Week $week",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text("Select Workout",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),

                const SizedBox(height: 12),

                ...daysForSelectedWeek.map((day) {
                  final locked = isDayLocked(day);
                  final completed = isDayCompleted(day);

                  final bgColor = locked
                      ? cs.surfaceVariant
                      : completed
                      ? cs.secondaryContainer
                      : cs.surface;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.onSurface.withOpacity(0.08),
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        "Workout Day $day",
                        style: TextStyle(
                          color: locked
                              ? cs.onSurface.withOpacity(0.4)
                              : cs.onSurface,
                        ),
                      ),
                      trailing: completed
                          ? Icon(Icons.check_circle, color: cs.secondary)
                          : locked
                          ? Icon(Icons.lock,
                          color:
                          cs.onSurface.withOpacity(0.35))
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
