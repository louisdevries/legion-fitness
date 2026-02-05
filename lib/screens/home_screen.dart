import 'package:flutter/material.dart';
import 'exercise_preview_screen.dart';
import '../models/home_state.dart';
import '../services/home_service.dart';
import '../services/exercise_generator.dart';

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

    try {
      List<Map<String, dynamic>> exercises;

      if (_state.nextWeek == 1) {
        // Week 1: Fetch directly from database
        exercises = await _homeService.fetchWeek1Exercises(
          programId: _state.programId!,
          weekNumber: _state.nextWeek!,
          dayNumber: _state.nextDay!,
        );
      } else {
        // Week 2+: Generate with progressive overload
        exercises = await _exerciseGenerator.generateProgressiveExercises(
          programId: _state.programId!,
          targetWeek: _state.nextWeek!,
          targetDay: _state.nextDay!,
        );
      }

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
      print("Error navigating to workout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading workout: $e')),
        );
      }
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
          const SizedBox(height: 20),
          _buildWeeklyProgressCard(),
          const SizedBox(height: 28),
          _buildActionSection(
            title: "Custom Programs",
            description: "Build or manage your workout plans",
            icon: Icons.fitness_center,
            route: '/create-program',
          ),
          const SizedBox(height: 16),
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

  Widget _buildResumeWorkoutBanner() {
    return GestureDetector(
      onTap: _state.isProgramComplete ? null : _navigateToWorkout,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 6),
            )
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
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _state.isProgramComplete
                        ? "🎉 Program completed"
                        : "Resume · Week ${_state.nextWeek} Day ${_state.nextDay}",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
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
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressCard() {
    const allDays = [1, 2, 3, 4, 5, 6, 7]; // Monday = 1, Sunday = 7
    final weekdayToday = DateTime.now().weekday;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "This Week",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: allDays.map((d) {
              final done = _state.completedDays[d] == true;
              final isToday = d == weekdayToday;

              Widget circle = Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? Colors.green : Colors.grey.shade700,
                  border: isToday
                      ? Border.all(color: Colors.blueAccent, width: 2.5)
                      : null,
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                    _dayLabel(d).substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );

              if (isToday && !done) {
                circle = AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent
                              .withOpacity(0.25 + (_pulseController.value * 0.25)),
                          blurRadius: 6 + (_pulseController.value * 6),
                        )
                      ],
                    ),
                    child: child,
                  ),
                  child: circle,
                );
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      circle,
                      const SizedBox(height: 4),
                      Text(
                        _dayLabel(d),
                        style: TextStyle(
                          fontSize: 11,
                          color: isToday ? Colors.blueAccent : Colors.white70,
                          fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _state.weekProgress,
            backgroundColor: Colors.white24,
            color: Colors.lightGreenAccent,
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Text(
            "${_state.completedDays.length} workout${_state.completedDays.length == 1 ? '' : 's'} this week",
            style: const TextStyle(fontSize: 12, color: Colors.white60),
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
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
