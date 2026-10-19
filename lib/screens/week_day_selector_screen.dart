import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/program_exercise_service.dart';
import '../services/program_completion_service.dart';
import '../services/cardio_day_service.dart';
import 'cardio_day_screen.dart';
import 'exercise_preview_screen.dart';
import 'exercise_runner_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:legion_fitness/main.dart';
import '../utils/user_prefs.dart';
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

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

  Map<String, ProgramDay> _programDaysByKey = {};
  Set<String> _completedCardioKeys = {};

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
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
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

      debugPrint('Reset: removed ${completionsDeleted.length} completions');

      // If nothing came back AND we know the user has rows for this
      // program (which is why they're hitting reset), RLS is likely
      // blocking. Surface this clearly.
      if (completionsDeleted.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reset returned no rows. Check Supabase RLS policies '
                  'allow DELETE on exercise_completions.',
            ),
            backgroundColor: AppTheme.danger,
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
          backgroundColor: AppTheme.danger,
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
            color: AppColors.of(context).card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.of(context).track,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Program exercises',
                  style: appDisplay(context, 28),
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

                        final placeholder =
                            const AppIconBadge(Icons.fitness_center, size: 56);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: mediaUrl != null && mediaUrl.isNotEmpty
                                      ? Image.network(
                                          mediaUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => placeholder,
                                        )
                                      : placeholder,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
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

      // Parallel fetch: cardio day metadata + user's cardio completions.
      _programDaysByKey =
          await CardioDayService.fetchProgramDays(widget.programId);
      _completedCardioKeys =
          await CardioDayService.fetchCompletedCardioKeys(widget.programId);

      final completion = await ProgramCompletionService.load(widget.programId);
      completedDaysByWeek
        ..clear()
        ..addAll(completion.completedDaysByWeek);
      highestUnlockedWeek = completion.highestUnlockedWeek;

      // Cardio days: complete when a cardio_day_completions row exists,
      // independent of exercise_completions (they have no exercises).
      for (final key in _completedCardioKeys) {
        final parts = key.split('-');
        final wk = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        completedDaysByWeek.putIfAbsent(wk, () => {}).add(day);
      }

      selectedWeek = 1;
      computeDays();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void computeDays() {
    final daysFromExercises = rows
        .where((r) => r['week_number'] == selectedWeek)
        .map((r) => r['day_number'] as int)
        .toSet();

    // Cardio days may have no program_exercises rows at all (pure cardio
    // days), so union in program_days for this week too.
    final daysFromProgramDays = _programDaysByKey.values
        .where((pd) => pd.weekNumber == selectedWeek)
        .map((pd) => pd.dayNumber)
        .toSet();

    daysForSelectedWeek = daysFromExercises.union(daysFromProgramDays).toList()
      ..sort();
  }

  ProgramDay? _programDayFor(int day) =>
      _programDaysByKey['$selectedWeek-$day'] ?? _programDaysByKey['1-$day'];

  bool isDayLocked(int day) {
    if (selectedWeek > highestUnlockedWeek) return true;
    if (day == 1) return false;
    return !(completedDaysByWeek[selectedWeek]?.contains(day - 1) ?? false);
  }

  bool isDayCompleted(int day) =>
      completedDaysByWeek[selectedWeek]?.contains(day) ?? false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
                        Icon(Icons.restart_alt, color: AppTheme.danger),
                        SizedBox(width: 8),
                        Text('Reset program',
                            style: TextStyle(color: AppTheme.danger)),
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
                      errorBuilder: (context, error, stack) =>
                          Container(color: const Color(0xFF181B22)),
                    )
                  else
                    Container(color: const Color(0xFF181B22)),

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
                          style: appDisplay(context, 36, color: Colors.white),
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
                      child: isActiveProgram
                          ? OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                side: BorderSide(color: c.accent, width: 1.4),
                              ),
                              icon: Icon(Icons.check_circle,
                                  color: c.accentText),
                              label: const Text('Program active'),
                              onPressed: _deactivateProgram,
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 52)),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start program'),
                              onPressed: _activateProgram,
                            ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52)),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Exercises'),
                      onPressed: _showAllExercises,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                const AppSectionTitle("Select week"),

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
                              ? c.track
                              : selected
                              ? c.accent
                              : c.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? c.accent : c.cardBorder,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (locked) ...[
                                Icon(Icons.lock, size: 13, color: c.muted),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                "Week $week",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? c.onAccent
                                      : locked
                                      ? c.muted
                                      : onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                const AppSectionTitle("Select workout"),

                const SizedBox(height: 12),

                ...daysForSelectedWeek.map((day) {
                  final locked = isDayLocked(day);
                  final completed = isDayCompleted(day);
                  final programDay = _programDayFor(day);
                  final isCardio = programDay?.isCardio == true;

                  final dayTitle = programDay?.title;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: locked ? c.track : c.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: completed
                            ? c.accent.withValues(alpha: 0.6)
                            : c.cardBorder,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      leading: AppIconBadge(
                        isCardio ? Icons.directions_run : Icons.fitness_center,
                        color: completed
                            ? c.onAccent
                            : locked
                            ? c.muted
                            : c.accentText,
                        background: completed ? c.accent : null,
                      ),
                      title: Text(
                        isCardio
                            ? (dayTitle ?? 'Cardio Day $day')
                            : "Day $day${dayTitle != null ? ' — $dayTitle' : ''}",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: locked ? c.muted : null,
                        ),
                      ),
                      subtitle: Text(
                        completed
                            ? 'Completed'
                            : locked
                            ? 'Locked'
                            : isCardio
                            ? 'Cardio'
                            : 'Strength',
                      ),
                      trailing: completed
                          ? Icon(Icons.check_circle, color: c.accentText)
                          : locked
                          ? Icon(Icons.lock, color: c.muted)
                          : Icon(Icons.arrow_forward_ios,
                              size: 16, color: c.muted),
                      onTap: locked
                          ? null
                          : () async {
                        if (isCardio) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CardioDayScreen(
                                programId: widget.programId,
                                weekNumber: selectedWeek,
                                dayNumber: day,
                              ),
                            ),
                          );
                          // Reload structure so the completion badge updates.
                          if (mounted) {
                            setState(() => isLoading = true);
                            loadProgramStructure();
                          }
                          return;
                        }

                        // Check for an existing in-progress session.
                        final prefs = await SharedPreferences.getInstance();
                        final sessionJson = prefs.getString('active_session');
                        bool hasSession = false;

                        if (sessionJson != null) {
                          try {
                            final data = jsonDecode(sessionJson) as Map<String, dynamic>;
                            hasSession =
                                data['programId'] == widget.programId &&
                                data['weekNumber'] == selectedWeek &&
                                data['dayNumber'] == day;
                          } catch (_) {}
                        }

                        if (hasSession && context.mounted) {
                          final choice = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Resume Workout?'),
                              content: const Text(
                                'You have an unfinished workout. Resume where you left off or start fresh?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, 'reset'),
                                  child: const Text('Start Fresh',
                                      style: TextStyle(color: AppTheme.danger)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, 'resume'),
                                  child: const Text('Resume'),
                                ),
                              ],
                            ),
                          );

                          if (!context.mounted) return;

                          if (choice == 'resume') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExerciseRunnerScreen(
                                  exercises: const [],
                                  programId: widget.programId,
                                  weekNumber: selectedWeek,
                                  dayNumber: day,
                                  resumeMode: true,
                                ),
                              ),
                            );
                            if (mounted) {
                              setState(() => isLoading = true);
                              loadProgramStructure();
                            }
                            return;
                          } else if (choice == 'reset') {
                            await prefs.remove('active_session');
                          } else {
                            // Dismissed — do nothing.
                            return;
                          }
                        }

                        AppSettings.showLoading();
                        try {
                          final exercises =
                              await ProgramExerciseService.fetchExercisesForDay(
                            programId: widget.programId,
                            weekNumber: selectedWeek,
                            dayNumber: day,
                          );

                          if (!context.mounted) return;

                          AppSettings.hideLoading();
                          await Navigator.push(
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
                          if (mounted) {
                            setState(() => isLoading = true);
                            loadProgramStructure();
                          }
                        } catch (e) {
                          AppSettings.hideLoading();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to load workout: $e"),
                                backgroundColor: AppTheme.danger,
                              ),
                            );
                          }
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