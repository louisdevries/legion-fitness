import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/program_exercise_service.dart';
import '../services/workout_engine_service.dart';
import 'exercise_preview_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:legion_fitness/main.dart';
import '../utils/user_prefs.dart';
import '../database/app_database.dart';

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
    final activeId = await UserPrefs.getInt('active_program_id');
    setState(() => isActiveProgram = activeId == widget.programId);
  }

  Future<void> _activateProgram() async {
    await UserPrefs.setInt('active_program_id', widget.programId);
    await UserPrefs.setInt('active_week_number', selectedWeek);

    setState(() => isActiveProgram = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Program activated')),
    );
  }

  Future<void> _deactivateProgram() async {
    await UserPrefs.remove('active_program_id');
    await UserPrefs.remove('active_week_number');

    setState(() => isActiveProgram = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Program deactivated')),
    );
  }

  Future<void> _confirmResetProgram() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Program'),
        content: const Text(
          'This will clear all your progress for this program and restart from Week 1, Day 1. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _resetProgram();
  }

  Future<void> _resetProgram() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Clear local SQLite logs first so SyncService can't re-insert
      // them into Supabase after the delete.
      await AppDatabase.instance.exerciseLogsDao
          .deleteLogsForProgram(widget.programId);

      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList('completion_queue') ?? [];
      if (queue.isNotEmpty) {
        await prefs.remove('completion_queue');
      }
      // Also clear any in-progress workout for this program — otherwise
      // the runner could resume mid-set on data that no longer exists.
      await prefs.remove('active_session');

      // Delete exercise_completions and verify rows were actually removed.
      // Supabase's delete returns success even if RLS blocks all rows;
      // adding .select() returns the deleted rows so we can detect this.
      final completionsDeleted = await supabase
          .from('exercise_completions')
          .delete()
          .eq('program_id', widget.programId)
          .eq('user_id', userId)
          .select();

      // Same for progress_logs — it has stale data from previous weeks
      // that the progression engine reads from.
      final logsDeleted = await supabase
          .from('progress_logs')
          .delete()
          .eq('program_id', widget.programId)
          .eq('user_id', userId)
          .select();

      debugPrint(
          'Reset: removed ${completionsDeleted.length} completions, '
              '${logsDeleted.length} progress logs');

      // If both came back empty AND we know the user has rows for this
      // program (which is why they're hitting reset), RLS is likely
      // blocking. Surface this clearly.
      if (completionsDeleted.isEmpty && logsDeleted.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reset returned no rows. Check Supabase RLS policies '
                  'allow DELETE on exercise_completions and progress_logs.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isActiveProgram) {
      await UserPrefs.setInt('active_week_number', 1);
    }

    setState(() {
      completedDaysByWeek.clear();
      highestUnlockedWeek = 1;
      selectedWeek = 1;
      isLoading = true;
    });

    await loadProgramStructure();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Program reset to Week 1')),
    );
  }

  Future<void> _showAllExercises() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Program Exercises',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchAllProgramExercises(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final exercises = snapshot.data ?? [];
                    if (exercises.isEmpty) {
                      return const Center(child: Text('No exercises found'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        final mediaUrl = exercise['media_url'] as String?;
                        final name = exercise['name'] as String? ?? 'Unknown';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: mediaUrl != null && mediaUrl.isNotEmpty
                                  ? Image.network(
                                      mediaUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.fitness_center),
                                      ),
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.fitness_center),
                                    ),
                            ),
                            title: Text(name),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllProgramExercises() async {
    final programExercises = await supabase
        .from('program_exercises')
        .select('exercise_id')
        .eq('program_id', widget.programId);

    final exerciseIds = (programExercises as List)
        .map((e) => e['exercise_id'] as int)
        .toSet()
        .toList();

    if (exerciseIds.isEmpty) return [];

    final exercises = await supabase
        .from('exercises')
        .select('id, name, media_url')
        .inFilter('id', exerciseIds);

    return List<Map<String, dynamic>>.from(exercises);
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

      final userId = supabase.auth.currentUser?.id;

      completedDaysByWeek.clear();

      if (userId != null) {
        // -----------------------------
        // STEP 1: REQUIRED EXERCISES PER DAY
        // -----------------------------
        final programExercises = await supabase
            .from('program_exercises')
            .select('week_number, day_number, exercise_id')
            .eq('program_id', widget.programId);

        final Map<String, Set<int>> requiredExercisesByDay = {};
        for (final pe in programExercises) {
          final key = '${pe['week_number']}-${pe['day_number']}';
          requiredExercisesByDay.putIfAbsent(key, () => <int>{});
          requiredExercisesByDay[key]!.add(pe['exercise_id'] as int);
        }

        // -----------------------------
        // STEP 2: COMPLETED EXERCISES PER DAY
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
        requiredExercisesByDay.forEach((key, required) {
          final completed = completedExercisesByDay[key] ?? <int>{};
          if (completed.length >= required.length) {
            final parts = key.split('-');
            final week = int.parse(parts[0]);
            final day = int.parse(parts[1]);
            completedDaysByWeek.putIfAbsent(week, () => {}).add(day);
          }
        });

        final week1Entries = requiredExercisesByDay.entries
            .where((e) => e.key.startsWith('1-'))
            .toList();
        for (int week = 2; week <= totalWeeks; week++) {
          for (final entry in week1Entries) {
            final day = int.parse(entry.key.split('-')[1]);
            final key = '$week-$day';
            final completed = completedExercisesByDay[key] ?? <int>{};
            if (completed.length >= entry.value.length) {
              completedDaysByWeek.putIfAbsent(week, () => {}).add(day);
            }
          }
        }
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
    // Always use week 1's day structure as reference, because weeks 2+ are
    // generated and have no rows in program_exercises. Without this, empty
    // weekDays.every(...) would be vacuously true and unlock all weeks.
    final week1Days = rows
        .where((r) => r['week_number'] == 1)
        .map((r) => r['day_number'] as int)
        .toSet();

    if (week1Days.isEmpty) return 1;

    int unlocked = 1;
    for (int week = 1; week <= totalWeeks; week++) {
      final completed = completedDaysByWeek[week] ?? {};
      if (week1Days.every(completed.contains)) {
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
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'reset') _confirmResetProgram();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.restart_alt, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Reset Program', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(isActiveProgram
                            ? Icons.check_circle
                            : Icons.play_arrow),
                        label: Text(
                            isActiveProgram ? 'Program Active' : 'Start Program'),
                        onPressed:
                            isActiveProgram ? _deactivateProgram : _activateProgram,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Exercises'),
                      onPressed: _showAllExercises,
                    ),
                  ],
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
                        AppSettings.showLoading();
                        try {
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
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to load workout: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          AppSettings.hideLoading();
                        }
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