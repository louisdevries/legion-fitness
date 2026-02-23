import 'package:flutter/material.dart';
import 'exercise_preview_screen.dart';
import '../models/home_state.dart';
import '../services/home_service.dart';
import '../services/exercise_generator.dart';
import 'custom_exercise_screen.dart';
import 'premium_program_screen.dart';
import '../main.dart'; // Import AppSettings

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _homeService = HomeService();
  final _exerciseGenerator = ExerciseGenerator();

  late HomeState _state;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _state = HomeState();
    _loadHomeData();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    final newState = await _homeService.loadHomeData();
    if (mounted) {
      setState(() => _state = newState);
    }
  }

  Future<void> _navigateToWorkout() async {
    if (_state.nextWeek == null || _state.nextDay == null) return;

    AppSettings.showLoading(); // Show universal loading

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading workout: $e')),
        );
      }
    } finally {
      AppSettings.hideLoading(); // Hide universal loading
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_state.programId == null) {
      return const Center(
        child: Text(
          "Select or create a program to get started 💪",
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildResumeWorkoutBanner(),
          const SizedBox(height: 24),
          _buildWeeklyProgressCard(),
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

          // Premium Program (NEW)
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
              premium: true, // NEW
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
    );
  }

  // ================= RESUME BANNER =================

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
              color: Colors.black.withOpacity(0.18),
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
                    Colors.black.withOpacity(0.75),
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

  // ================= WEEKLY PROGRESS =================

  Widget _buildWeeklyProgressCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.28 : 0.10,
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
                            : theme.colorScheme.onSurface.withOpacity(0.15),
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
                            : theme.colorScheme.onSurface.withOpacity(0.7),
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

  // ================= ACTION CARDS =================

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

    // Adaptive colors
    Color cardColor;
    Color iconColor;
    Color iconBackgroundColor;

    if (premium) {
      if (theme.brightness == Brightness.dark) {
        cardColor = Colors.orange.shade800; // dark amber for dark mode
        iconBackgroundColor = Colors.orange.shade600.withOpacity(0.25);
        iconColor = Colors.orange.shade200;
      } else {
        cardColor = Colors.amber.shade100; // light amber for light mode
        iconBackgroundColor = Colors.amber.shade600.withOpacity(0.15);
        iconColor = Colors.amber.shade800;
      }
    } else {
      cardColor = theme.colorScheme.surface;
      iconBackgroundColor = theme.colorScheme.primary.withOpacity(0.15);
      iconColor = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.30 : 0.12,
            ),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBackgroundColor,
            ),
            child: Icon(icon, size: 26, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: premium && theme.brightness == Brightness.dark
                        ? Colors.white
                        : null, // ensures readable text
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: premium && theme.brightness == Brightness.dark
                        ? Colors.white70
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ],
      ),
    );
  }


  String _dayLabel(int d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d - 1];
  }
}
