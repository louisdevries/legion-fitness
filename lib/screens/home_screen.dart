import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'exercise_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  int? programId;
  int currentWeek = 1;

  String? programName;
  String? programImage;

  Map<int, bool> completedDays = {};
  int? nextWeek;
  int? nextDay;

  double programProgress = 0.0;
  double weekProgress = 0.0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
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
    final prefs = await SharedPreferences.getInstance();
    programId = prefs.getInt('active_program_id');
    currentWeek = prefs.getInt('active_week_number') ?? 1;

    final lastWeek = prefs.getInt('last_seen_week');
    final nowWeek = _weekOfYear(DateTime.now());

    if (lastWeek != nowWeek) {
      currentWeek = 1;
      await prefs.setInt('active_week_number', 1);
      await prefs.setInt('last_seen_week', nowWeek);
    }

    if (programId == null) {
      setState(() => isLoading = false);
      return;
    }

    await _loadProgramInfo();
    await _loadProgress();
    setState(() => isLoading = false);
  }

  Future<void> _loadProgramInfo() async {
    final data = await supabase
        .from('fitness_programs')
        .select('name, image_url')
        .eq('id', programId!)
        .maybeSingle();

    if (data != null) {
      programName = data['name'];
      programImage = data['image_url'];
    }
  }

  Future<void> _loadProgress() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final allExercises = await supabase
        .from('program_exercises')
        .select('week_number, day_number')
        .eq('program_id', programId!);

    final completedLogs = await supabase
        .from('progress_logs')
        .select('week_number, day_number')
        .eq('user_id', user.id)
        .eq('program_id', programId!);

    final doneSet = <String>{};
    for (final log in completedLogs as List) {
      doneSet.add("${log['week_number']}-${log['day_number']}");
    }

    programProgress =
    allExercises.isNotEmpty ? doneSet.length / allExercises.length : 0.0;

    nextWeek = null;
    nextDay = null;
    for (final e in allExercises as List) {
      final key = "${e['week_number']}-${e['day_number']}";
      if (!doneSet.contains(key)) {
        nextWeek = e['week_number'];
        nextDay = e['day_number'];
        break;
      }
    }

    completedDays.clear();
    int totalDaysThisWeek = 0;
    int completedDaysThisWeek = 0;
    final weekdayToday = DateTime.now().weekday;

    for (final e in allExercises) {
      if (e['week_number'] == currentWeek) {
        final dayNum = e['day_number'];
        totalDaysThisWeek++;

        final key = "${e['week_number']}-${dayNum}";
        if (doneSet.contains(key) && dayNum < weekdayToday) {
          completedDays[dayNum] = true;
          completedDaysThisWeek++;
        }
      }
    }

    weekProgress = totalDaysThisWeek > 0
        ? completedDaysThisWeek / totalDaysThisWeek
        : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (programId == null) {
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
          _resumeWorkoutBanner(),
          const SizedBox(height: 20),
          _weeklyProgressCard(),
          const SizedBox(height: 28),
          _largeActionSection(
            title: "Custom Programs",
            description: "Build or manage your workout plans",
            icon: Icons.fitness_center,
            route: '/create-program',
          ),
          const SizedBox(height: 16),
          _largeActionSection(
            title: "Meal Suggestions",
            description: "Nutrition to support your training",
            icon: Icons.restaurant,
            route: '/meal-suggestions',
          ),
        ],
      ),
    );
  }

  // -------------------- Active Program Banner --------------------
  Widget _resumeWorkoutBanner() {
    return GestureDetector(
      onTap: nextDay == null
          ? null
          : () async {
        final exercises = await supabase
            .from('program_exercises')
            .select('*')
            .eq('program_id', programId!)
            .eq('week_number', nextWeek!)
            .eq('day_number', nextDay!)
            .order('id')
            .then((v) => v as List<Map<String, dynamic>>);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExercisePreviewScreen(
              exercises: exercises,
              programId: programId!,
              weekNumber: nextWeek!,
              dayNumber: nextDay!,
            ),
          ),
        );
      },
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
            if (programImage != null)
              Image.network(programImage!, fit: BoxFit.cover)
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
                    programName ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    programProgress >= 1.0
                        ? "🎉 Program completed"
                        : "Resume · Week $nextWeek Day $nextDay",
                    style:
                    const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: programProgress,
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

  // -------------------- Weekly Progress --------------------
  Widget _weeklyProgressCard() {
    const allDays = [1, 2, 3, 4, 5, 6, 7];
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
            children: allDays.map((d) {
              final done = completedDays[d] == true;
              final isToday = d == weekdayToday;
              final future = d > weekdayToday;

              Widget circle = Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? Colors.green
                      : future
                      ? Colors.grey.shade800
                      : Colors.grey.shade700,
                  border: isToday
                      ? Border.all(color: Colors.blueAccent, width: 2)
                      : null,
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check,
                      color: Colors.white, size: 20)
                      : Text("$d",
                      style:
                      const TextStyle(color: Colors.white)),
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
                          color: Colors.blueAccent.withOpacity(
                              0.25 + (_pulseController.value * 0.25)),
                          blurRadius:
                          6 + (_pulseController.value * 6),
                        )
                      ],
                    ),
                    child: child,
                  ),
                  child: circle,
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    circle,
                    const SizedBox(height: 4),
                    Text(_dayLabel(d),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: weekProgress,
            backgroundColor: Colors.white24,
            color: Colors.lightGreenAccent,
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  // -------------------- Large Action Sections --------------------
  Widget _largeActionSection({
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

  int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    return ((date.difference(firstDay).inDays + firstDay.weekday) / 7).ceil();
  }
}
