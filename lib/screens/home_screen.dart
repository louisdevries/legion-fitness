import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart'; // AppSettings
import '../models/home_state.dart';
import '../models/local_custom_program.dart';
import '../models/meal_log.dart';
import '../services/achievement_service.dart';
import '../services/cardio_day_service.dart';
import '../services/exercise_generator.dart';
import '../services/food_service.dart';
import '../services/home_service.dart';
import '../services/local_program_service.dart';
import '../services/nutrition_targets_service.dart';
import '../services/xp_service.dart';
import '../theme/app_theme.dart';
import 'achievements_screen.dart';
import 'cardio_day_screen.dart';
import 'custom_exercise_screen.dart';
import 'exercise_preview_screen.dart';
import 'exercise_runner_screen.dart';
import 'meals_screen.dart';
import 'premium_program_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToPrograms;
  final VoidCallback? onGoToProfile;
  const HomeScreen({super.key, this.onGoToPrograms, this.onGoToProfile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeService = HomeService();
  final _exerciseGenerator = ExerciseGenerator();
  List<AchievementRow> _recentUnlocks = [];

  StreamSubscription<AuthState>? _authSub;
  late HomeState _state;
  XpSummary _xpSummary = const XpSummary.empty();
  String? _firstName;
  List<LocalCustomProgram> _customPrograms = [];

  // Today's food
  List<MealLog> _todayMeals = [];
  NutritionTargets? _targets;

  // ================= HEALTH CONNECT =================
  final Health _health = Health();
  int _steps = 0;
  bool _healthAuthorized = false;

  static const _dailyStepGoal = 10000;

  bool get _signedIn => Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _state = HomeState();

    if (AppSettings.googleFitEnabled.value) _initHealth();
    AppSettings.googleFitEnabled.addListener(_onGoogleFitChanged);

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (mounted) _loadAll();
    });

    _loadAll();
  }

  @override
  void dispose() {
    AppSettings.googleFitEnabled.removeListener(_onGoogleFitChanged);
    _authSub?.cancel();
    super.dispose();
  }

  void _loadAll() {
    _loadHomeData();
    _loadRecentUnlocks();
    _loadXp();
    _loadName();
    _loadCustomPrograms();
    _loadFood();
  }

  void _onGoogleFitChanged() {
    if (AppSettings.googleFitEnabled.value) {
      _initHealth();
    } else {
      if (mounted) setState(() { _healthAuthorized = false; _steps = 0; });
    }
  }

  Future<void> _loadHomeData() async {
    final newState = await _homeService.loadHomeData();
    if (mounted) {
      setState(() => _state = newState);
    }
  }

  Future<void> _loadXp() async {
    final summary = await XpService.fetchSummary();
    if (!mounted) return;
    setState(() => _xpSummary = summary);
  }

  Future<void> _loadName() async {
    final name = await _homeService.loadFirstName();
    if (mounted) setState(() => _firstName = name);
  }

  Future<void> _loadCustomPrograms() async {
    final programs = await LocalProgramService.loadAll();
    if (mounted) setState(() => _customPrograms = programs);
  }

  Future<void> _loadFood({bool refresh = false}) async {
    if (!_signedIn) return;
    try {
      final today = DateTime.now();
      if (refresh) await FoodService.refreshDay(today);
      final meals = await FoodService.getMealsForDay(today);
      final targets = await NutritionTargetsService.getTargets();
      if (!mounted) return;
      setState(() {
        _todayMeals = meals;
        _targets = targets;
      });
    } catch (e) {
      debugPrint('Home food load failed: $e');
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadHomeData(),
      _loadRecentUnlocks(),
      _loadXp(),
      _loadCustomPrograms(),
      _loadFood(refresh: true),
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
    final granted = await _health.hasPermissions(types, permissions: permissions) ?? false;
    if (mounted) setState(() => _healthAuthorized = granted);
    if (granted) await _fetchSteps();
  }

  Future<void> _requestPermissions() async {
    await AppSettings.setGoogleFitEnabled(true);
    await _health.configure();
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];
    await _health.requestAuthorization(types, permissions: permissions);
    final granted = await _health.hasPermissions(types, permissions: permissions) ?? false;
    if (!granted) await AppSettings.setGoogleFitEnabled(false);
    if (mounted) setState(() => _healthAuthorized = granted);
    if (granted) await _fetchSteps();
  }

  Future<void> _fetchSteps() async {
    if (!_healthAuthorized) return;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      final steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      if (mounted) setState(() => _steps = steps);

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
        final xpGrants = await XpService.onStepsLogged(stepsToday: _steps);
        if (mounted && xpGrants.isNotEmpty) {
          _loadXp(); // refresh banner immediately
          for (final g in xpGrants) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(g.isLevelUp
                    ? '+${g.amount} XP — Level ${g.newLevel}!'
                    : '+${g.amount} XP · ${g.label}'),
              ),
            );
          }
        }
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

    // Cardio days have no exercises to run — route to the cardio screen
    // instead of the workout preview/runner flow below.
    final programDays =
        await CardioDayService.fetchProgramDays(_state.programId!);
    final programDay = programDays['${_state.nextWeek}-${_state.nextDay}'] ??
        programDays['1-${_state.nextDay}'];
    if (programDay?.isCardio == true) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardioDayScreen(
            programId: _state.programId!,
            weekNumber: _state.nextWeek!,
            dayNumber: _state.nextDay!,
          ),
        ),
      );
      if (mounted) _loadHomeData();
      return;
    }

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
          if (!mounted) return;
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => ExerciseRunnerScreen(
              exercises: const [],
              programId: _state.programId!,
              weekNumber: _state.nextWeek!,
              dayNumber: _state.nextDay!,
              resumeMode: true,
            ),
          ));
          if (mounted) _loadHomeData();
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

      AppSettings.hideLoading();
      await Navigator.push(
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
      if (mounted) _loadHomeData();
    } catch (e) {
      AppSettings.hideLoading();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading workout: $e')));
      }
    }
  }

  Future<void> _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    if (_state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget pad(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        );

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          children: [
            pad(_buildHeader()),
            if (_signedIn) ...[
              const SizedBox(height: 16),
              pad(_buildXpCard()),
            ],
            const SizedBox(height: 12),
            pad(_buildHeroCard()),
            const SizedBox(height: 12),
            pad(_buildWeekCard()),
            const SizedBox(height: 12),
            pad(IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildStepsCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCaloriesCard()),
                ],
              ),
            )),
            if (_recentUnlocks.isNotEmpty) ...[
              const SizedBox(height: 12),
              pad(_buildRecentUnlocksCard()),
            ],
            const SizedBox(height: 24),
            pad(_buildProgramsHeader()),
            const SizedBox(height: 12),
            _buildProgramsCarousel(),
          ],
        ),
      ),
    );
  }

  // ================= SHARED BITS =================

  Widget _card({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Color? borderColor,
  }) {
    final c = AppColors.of(context);
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor ?? c.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  TextStyle _display(double size, {Color? color}) => TextStyle(
        fontFamily: AppTheme.displayFont,
        fontWeight: FontWeight.w800,
        fontSize: size,
        height: 1.05,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );

  Widget _bar(double value, {double height = 6}) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: c.track,
        valueColor: AlwaysStoppedAnimation(c.accent),
      ),
    );
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

  // ================= HEADER =================

  Widget _buildHeader() {
    final c = AppColors.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    Widget circleButton({
      required IconData icon,
      required Color color,
      required Color border,
      required String tooltip,
      required VoidCallback? onTap,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: CircleBorder(side: BorderSide(color: border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: TextStyle(color: c.muted, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                _firstName ?? (_signedIn ? 'Welcome back' : 'Welcome'),
                style: _display(32),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        circleButton(
          icon: Icons.workspace_premium_outlined,
          color: c.premium,
          border: c.premium.withValues(alpha: 0.5),
          tooltip: 'Premium',
          onTap: () => _push(const PremiumProgramScreen()),
        ),
        const SizedBox(width: 10),
        circleButton(
          icon: Icons.person_outline,
          color: Theme.of(context).colorScheme.onSurface,
          border: c.cardBorder,
          tooltip: 'Profile',
          onTap: widget.onGoToProfile,
        ),
      ],
    );
  }

  // ================= XP =================

  Widget _buildXpCard() {
    final c = AppColors.of(context);
    final s = _xpSummary;
    final toNext = (s.xpForLevel - s.xpIntoLevel).clamp(0, s.xpForLevel);

    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${s.level}', style: _display(22, color: c.onAccent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Level ${s.level}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      '${_thousands(toNext)} XP to Level ${s.level + 1}',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _bar(s.progress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= HERO (resume / choose program) =================

  Widget _buildHeroCard() {
    final hasProgram = _state.programId != null && _signedIn;

    if (!hasProgram) {
      return _heroShell(
        eyebrow: 'GET STARTED',
        title: 'Choose a program',
        subtitle: 'Pick a plan and start training today',
        buttonLabel: 'Browse programs',
        buttonIcon: Icons.arrow_forward,
        onPressed: widget.onGoToPrograms,
      );
    }

    if (_state.isProgramComplete) {
      return _heroShell(
        eyebrow: 'PROGRAM COMPLETE',
        title: _state.programName ?? 'Program',
        subtitle: 'Every session done. Time for the next challenge 🎉',
        buttonLabel: 'Choose next program',
        buttonIcon: Icons.arrow_forward,
        onPressed: widget.onGoToPrograms,
      );
    }

    final day = _state.nextDay!;
    final title = _state.nextDayTitle;
    final chips = <String>[
      if (_state.nextDayIsCardio) 'Cardio',
      if (_state.nextDayExerciseCount != null)
        '${_state.nextDayExerciseCount} exercise${_state.nextDayExerciseCount == 1 ? '' : 's'}',
      if (_state.nextDayMinutes != null)
        _state.nextDayIsCardio
            ? 'At least ${_state.nextDayMinutes} min'
            : 'About ${_state.nextDayMinutes} min',
    ];

    return _heroShell(
      eyebrow: 'RESUME PROGRAM',
      title: _state.programName ?? 'Your program',
      subtitle: 'Week ${_state.nextWeek} · Day $day'
          '${title != null && title.isNotEmpty ? ' — $title' : ''}',
      chips: chips,
      buttonLabel: 'Start Day $day',
      buttonIcon: Icons.play_arrow_rounded,
      onPressed: _navigateToWorkout,
    );
  }

  Widget _heroShell({
    required String eyebrow,
    required String title,
    required String subtitle,
    List<String> chips = const [],
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback? onPressed,
  }) {
    final c = AppColors.of(context);
    final ink = c.onAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(title, style: _display(32, color: ink)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ink, width: 1.2),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        color: ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(buttonIcon, color: c.accent),
              label: Text(
                buttonLabel,
                style: TextStyle(
                  color: c.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= YOUR WEEK =================

  Widget _buildWeekCard() {
    final c = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final today = DateTime.now().weekday;
    final done = _state.completedDays.values.where((v) => v).length;
    final perWeek = _state.daysPerWeek;

    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    Widget dayMarker(int d) {
      final trained = _state.completedDays[d] == true;
      const size = 38.0;

      if (trained) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, color: c.onAccent, size: 22),
        );
      }
      if (d == today) {
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.accent, width: 2),
          ),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          ),
        );
      }
      if (d > today) {
        return CustomPaint(
          size: const Size(size, size),
          painter: _DashedCirclePainter(color: c.muted),
        );
      }
      // Past day without a workout.
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: c.muted, shape: BoxShape.circle),
          ),
        ),
      );
    }

    Widget legend(Widget marker, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            marker,
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
          ],
        );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Your week', style: _display(26)),
              const Spacer(),
              Text(
                perWeek > 0 && _state.programId != null
                    ? '$done of $perWeek workouts done'
                    : '$done workout${done == 1 ? '' : 's'} done',
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        labels[d - 1],
                        style: TextStyle(
                          fontSize: 12,
                          color: d == today ? onSurface : c.muted,
                          fontWeight:
                              d == today ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      dayMarker(d),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              legend(
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: c.accent, shape: BoxShape.circle),
                ),
                'Trained',
              ),
              legend(
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.accent, width: 1.5),
                  ),
                ),
                'Today',
              ),
              legend(
                CustomPaint(
                  size: const Size(9, 9),
                  painter: _DashedCirclePainter(color: c.muted, dashes: 6),
                ),
                'Upcoming',
              ),
              legend(
                Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: c.muted, shape: BoxShape.circle),
                ),
                'Rest',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= STEPS & CALORIES =================

  Widget _statCard({
    required String label,
    required String value,
    required double progress,
    required String caption,
    VoidCallback? onTap,
    bool showChevron = false,
    Widget? action,
  }) {
    final c = AppColors.of(context);
    return _card(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: c.muted, fontSize: 14)),
              const Spacer(),
              if (showChevron)
                Icon(Icons.chevron_right, size: 20, color: c.muted),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: _display(38)),
          const SizedBox(height: 10),
          _bar(progress, height: 7),
          const SizedBox(height: 10),
          Text(
            caption,
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.35),
          ),
          if (action != null) ...[const SizedBox(height: 6), action],
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    final c = AppColors.of(context);
    if (!_healthAuthorized) {
      return _statCard(
        label: 'Steps',
        value: '—',
        progress: 0,
        caption: 'Connect Health Connect to count your steps.',
        onTap: _requestPermissions,
        action: Text(
          'Connect',
          style: TextStyle(
            color: c.accentText,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
    }
    return _statCard(
      label: 'Steps',
      value: _thousands(_steps),
      progress: _steps / _dailyStepGoal,
      caption: _steps >= _dailyStepGoal
          ? 'Goal reached 🎉'
          : 'Goal ${_thousands(_dailyStepGoal)}',
    );
  }

  Widget _buildCaloriesCard() {
    Future<void> openMeals() async {
      await _push(const MealsScreen());
      _loadFood();
    }

    if (!_signedIn) {
      return _statCard(
        label: 'Calories',
        value: '—',
        progress: 0,
        caption: 'Log in to track meals.',
      );
    }

    final kcal = _todayMeals.fold<double>(0, (s, m) => s + m.kcal).round();
    final target = _targets?.kcal;

    // Nudge for the meal that's due by now but missing.
    final hour = DateTime.now().hour;
    final dueMeal = hour >= 18
        ? 'dinner'
        : hour >= 13
            ? 'lunch'
            : hour >= 9
                ? 'breakfast'
                : null;
    final missing = dueMeal != null &&
        !_todayMeals.any((m) => m.mealType == dueMeal);
    final nudge = missing
        ? '${dueMeal[0].toUpperCase()}${dueMeal.substring(1)} not logged'
        : null;

    final caption = [
      if (target != null) 'of ${_thousands(target)}' else 'Set a daily target',
      ?nudge,
    ].join(' · ');

    return _statCard(
      label: 'Calories',
      value: _thousands(kcal),
      progress: target == null ? 0 : kcal / target,
      caption: caption,
      onTap: openMeals,
      showChevron: true,
    );
  }

  // ================= RECENT UNLOCKS =================

  Widget _buildRecentUnlocksCard() {
    final c = AppColors.of(context);
    return _card(
      onTap: () => _push(const AchievementsScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: c.premium, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Recent unlocks',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const Spacer(),
              Text(
                'View all',
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          for (final a in _recentUnlocks)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.premium.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.workspace_premium,
                        size: 16, color: c.premium),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ================= PROGRAMS CAROUSEL =================

  Widget _buildProgramsHeader() {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Programs', style: _display(28)),
        const Spacer(),
        Text('Swipe for more', style: TextStyle(color: c.muted, fontSize: 13)),
      ],
    );
  }

  Widget _buildProgramsCarousel() {
    final c = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Future<void> openCustom() async {
      await _push(const CustomExerciseScreen());
      _loadCustomPrograms();
    }

    Widget programCard({
      required Widget icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color? borderColor,
      bool dashed = false,
    }) {
      final content = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.muted, fontSize: 12, height: 1.3),
            ),
          ],
        ),
      );

      return SizedBox(
        width: 156,
        child: dashed
            ? CustomPaint(
                painter: _DashedRRectPainter(color: c.muted, radius: 20),
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: onTap, child: content),
                ),
              )
            : Material(
                color: c.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: borderColor ?? c.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: onTap, child: content),
              ),
      );
    }

    Widget iconBox(IconData icon, Color color, {Color? background}) =>
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: background ?? c.track,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        );

    final cards = <Widget>[
      programCard(
        dashed: true,
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          child: Icon(Icons.add, color: c.onAccent),
        ),
        title: 'Create your own',
        subtitle: 'Pick from the exercise library',
        onTap: openCustom,
      ),
      for (final p in _customPrograms)
        programCard(
          icon: iconBox(Icons.fitness_center, c.accentText),
          title: p.name,
          subtitle: 'Yours · ${p.daysPerWeek} day${p.daysPerWeek == 1 ? '' : 's'}',
          onTap: openCustom,
        ),
      programCard(
        borderColor: c.premium.withValues(alpha: 0.6),
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.premium.withValues(alpha: 0.6)),
          ),
          child: Icon(Icons.workspace_premium_outlined,
              color: c.premium, size: 22),
        ),
        title: 'Premium Program',
        subtitle: 'Designed just for you',
        onTap: () => _push(const PremiumProgramScreen()),
      ),
      programCard(
        icon: iconBox(Icons.grid_view_rounded, onSurface),
        title: 'Browse all',
        subtitle: 'Find your next program',
        onTap: () => widget.onGoToPrograms?.call(),
      ),
    ];

    return SizedBox(
      height: 172,
      child: ScrollConfiguration(
        // No scrollbar on the carousel.
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => cards[i],
        ),
      ),
    );
  }
}

// ================= PAINTERS =================

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashes;
  const _DashedCirclePainter({required this.color, this.dashes = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    final sweep = 2 * 3.141592653589793 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(1), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) =>
      old.color != color || old.dashes != dashes;
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.75),
        Radius.circular(radius),
      ));
    const dash = 6.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
