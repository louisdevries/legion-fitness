import 'dart:async';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'exercise_preview_screen.dart';
import '../models/home_state.dart';
import '../services/home_service.dart';
import '../services/exercise_generator.dart';
import 'custom_exercise_screen.dart';
import 'premium_program_screen.dart';
import '../main.dart'; // AppSettings
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exercise_runner_screen.dart';
import 'dart:convert';
import '../services/achievement_service.dart';
import 'achievements_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToPrograms;
  const HomeScreen({super.key, this.onGoToPrograms});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _homeService = HomeService();
  final _exerciseGenerator = ExerciseGenerator();
  List<AchievementRow> _recentUnlocks = [];

  StreamSubscription<AuthState>? _authSub;
  late HomeState _state;
  late AnimationController _pulseController;

  // ================= HEALTH CONNECT =================
  final Health _health = Health();
  int _steps = 0;
  bool _healthAuthorized = false;

  @override
  void initState() {
    super.initState();
    _state = HomeState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initHealth();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (mounted) {
        _loadHomeData();
        _loadRecentUnlocks();
      }
    });

    _loadHomeData();
    _loadRecentUnlocks();
  }



  @override
  void dispose() {
    _authSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    final newState = await _homeService.loadHomeData();
    if (mounted) {
      setState(() => _state = newState);
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadHomeData(),
      _loadRecentUnlocks(),
      _fetchSteps(),
    ]);
  }

  Future<void> _loadRecentUnlocks() async {
    try {
      final all = await AchievementService.fetchAll();
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final recent = all
          .where((a) =>
      a.isUnlocked &&
          a.unlockedAt != null &&
          a.unlockedAt!.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
      if (!mounted) return;
      setState(() => _recentUnlocks = recent.take(2).toList());
    } catch (_) {
      // Silent failure — the card just won't show.
    }
  }

  // ================= HEALTH CONNECT =================

  Future<void> _initHealth() async {
    await _health.configure();
    await _checkAndFetchSteps();
  }

  Future<void> _checkAndFetchSteps() async {
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    // Check if already granted first
    final alreadyGranted = await _health.hasPermissions(types, permissions: permissions) ?? false;

    if (alreadyGranted) {
      if (mounted) setState(() => _healthAuthorized = true);
      await _fetchSteps();
      return;
    }

    // Not granted yet — request it
    await _health.requestAuthorization(types, permissions: permissions);

    // Re-check after request since Android returns false even when granted
    final confirmedGranted = await _health.hasPermissions(types, permissions: permissions) ?? false;

    if (mounted) setState(() => _healthAuthorized = confirmedGranted);

    if (confirmedGranted) {
      await _fetchSteps();
    }
  }

  Future<void> _requestPermissions() async {
    await _checkAndFetchSteps();
  }

  Future<void> _fetchSteps() async {
    if (!_healthAuthorized) return;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      final steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      if (mounted) setState(() => _steps = steps);

      // ✅ Save to Supabase
      // ✅ Save to Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('daily_steps').upsert({
          'user_id': user.id,
          'date': DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10),
          'steps': steps,
        }, onConflict: 'user_id,date');

        // ── Achievement progress ──────────────────────────────────
        final unlocked = await AchievementService.onStepsLogged(
          stepsToday: steps,
        );
        if (mounted && unlocked.isNotEmpty) {
          _loadRecentUnlocks();
          for (final a in unlocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('🏆 Unlocked: ${a.label}')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch steps: $e');
    }

    if (mounted) {
      Future.delayed(const Duration(seconds: 30), _fetchSteps);
    }
  }

  // ================= NAVIGATION =================

  Future<bool?> _showResumeDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Resume workout?"),
        content: const Text(
          "You have an unfinished workout. Do you want to continue where you left off?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Restart"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Resume"),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToWorkout() async {
    if (_state.nextWeek == null || _state.nextDay == null) return;

    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('active_session');

    if (savedJson != null) {
      final savedData = jsonDecode(savedJson) as Map<String, dynamic>;
      final savedProgram = savedData['programId'] as int?;
      final savedWeek    = savedData['weekNumber'] as int?;
      final savedDay     = savedData['dayNumber'] as int?;
      final timestamp    = savedData['timestamp'] as int? ?? 0;
      final expired      = DateTime.now().millisecondsSinceEpoch - timestamp > 3 * 60 * 60 * 1000;

      // Only offer resume if it's for THIS workout and not expired.
      if (!expired &&
          savedProgram == _state.programId &&
          savedWeek == _state.nextWeek &&
          savedDay == _state.nextDay) {
        final shouldResume = await _showResumeDialog();
        if (shouldResume == null) return;
        if (shouldResume) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ExerciseRunnerScreen(
              exercises: const [],
              programId: _state.programId!,
              weekNumber: _state.nextWeek!,
              dayNumber: _state.nextDay!,
              resumeMode: true,
            ),
          ));
          return;
        }
        await prefs.remove('active_session');
      } else if (expired) {
        // Clean up stale session silently.
        await prefs.remove('active_session');
      }
    }

    // 🔁 Normal flow (preview + countdown)
    AppSettings.showLoading();

    try {
      final exercises = _state.nextWeek == 1
          ? await _homeService.fetchWeek1Exercises(
        programId: _state.programId!,
        weekNumber: _state.nextWeek!,
        dayNumber: _state.nextDay!,
      )
          : await _exerciseGenerator.generateProgressiveExercises(
        programId: _state.programId!,
        targetWeek: _state.nextWeek!,
        targetDay: _state.nextDay!,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExercisePreviewScreen(
            exercises: exercises,
            programId: _state.programId!,
            weekNumber: _state.nextWeek!,
            dayNumber: _state.nextDay!,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading workout: $e')));
      }
    } finally {
      AppSettings.hideLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
        children: [
          _state.programId != null &&
                  Supabase.instance.client.auth.currentUser != null
              ? _buildResumeWorkoutBanner()
              : _buildChooseProgramBanner(),
          const SizedBox(height: 24),
          _buildWeeklyProgressCard(),
          const SizedBox(height: 16),
          _buildStepCounterCard(),
          if (_recentUnlocks.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRecentUnlocksCard(),
          ],
          const SizedBox(height: 32),

          // Custom Programs
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomExerciseScreen(),
                ),
              );
            },
            child: _buildActionSectionStatic(
              title: "Custom Programs",
              description: "Build or manage your workout plans",
              icon: Icons.fitness_center,
            ),
          ),

          const SizedBox(height: 18),

          // Premium Program
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PremiumProgramScreen(),
                ),
              );
            },
            child: _buildActionSectionStatic(
              title: "Premium Program",
              description: "Get a program designed just for you",
              icon: Icons.workspace_premium,
              premium: true,
            ),
          ),

          const SizedBox(height: 18),

          // Meal Suggestions
          _buildActionSection(
            title: "Meal Suggestions",
            description: "Nutrition to support your training",
            icon: Icons.restaurant,
            route: '/meal-suggestions',
          ),
        ],
        ),
      ),
    );
  }

  // ================= STEP COUNTER CARD =================

  Widget _buildStepCounterCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withAlpha(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              theme.brightness == Brightness.dark ? 72 : 26,
            ),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withAlpha(38),
            ),
            child: Icon(Icons.directions_walk,
                size: 30, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Daily Steps",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "$_steps steps",
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                    fontSize: 14,
                  ),
                ),
                if (!_healthAuthorized)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: _requestPermissions,
                      child: const Text(
                        "Enable Health access",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= CHOOSE PROGRAM BANNER =================

  Widget _buildChooseProgramBanner() {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onGoToPrograms,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.85),
              theme.colorScheme.primary.withValues(alpha: 0.5),
            ],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.fitness_center,
                size: 160,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Choose a Program",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Pick a plan and start training today",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Browse",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward,
                                color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= RESUME WORKOUT BANNER =================

  Widget _buildResumeWorkoutBanner() {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _state.isProgramComplete ? null : _navigateToWorkout,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_state.programImage != null)
              Image.network(_state.programImage!, fit: BoxFit.cover)
            else
              Container(color: Colors.grey.shade800),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _state.programName ?? '',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _state.isProgramComplete
                        ? "🎉 Program completed"
                        : "Resume · Week ${_state.nextWeek} Day ${_state.nextDay}",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _state.programProgress,
                    backgroundColor: Colors.white24,
                    color: Colors.greenAccent,
                    minHeight: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.28 : 0.10,
            ),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "This Week",
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(7, (i) {
              final d = i + 1;
              final done = _state.completedDays[d] == true;
              final isToday = d == DateTime.now().weekday;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? Colors.green
                            : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                        border: isToday
                            ? Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        )
                            : null,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check,
                            color: Colors.white, size: 20)
                            : Text(
                          _dayLabel(d)[0],
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dayLabel(d),
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                        fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection({
    required String title,
    required String description,
    required IconData icon,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: _buildActionSectionStatic(
        title: title,
        description: description,
        icon: icon,
      ),
    );
  }

  Widget _buildActionSectionStatic({
    required String title,
    required String description,
    required IconData icon,
    bool premium = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: premium
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.28 : 0.10,
            ),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 26, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentUnlocksCard() {
    if (_recentUnlocks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AchievementsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  "Recent Unlocks",
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  "View all",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._recentUnlocks.map((a) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.workspace_premium,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.label,
                      style:
                      const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _dayLabel(int d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d - 1];
  }
}