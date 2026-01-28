import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<int, bool> completedDays = {};
  bool isLoading = true;

  int? programId;
  int? weekNumber;
  int? nextWorkoutDay;

  @override
  void initState() {
    super.initState();
    _loadActiveProgram();
  }

  // ---------------- Load active program from shared prefs ----------------
  Future<void> _loadActiveProgram() async {
    final prefs = await SharedPreferences.getInstance();
    programId = prefs.getInt('active_program_id');
    weekNumber = prefs.getInt('active_week_number');

    if (programId == null || weekNumber == null) {
      setState(() => isLoading = false);
      return;
    }

    await _loadWeekStatus();
  }

  // ---------------- Load weekly progress from progress_logs ----------------
  Future<void> _loadWeekStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    Map<int, bool> temp = {};

    // Check each day 1–7
    for (int day = 1; day <= 7; day++) {
      try {
        final data = await Supabase.instance.client
            .from('progress_logs')
            .select('*')
            .eq('user_id', user.id)
            .eq('program_id', programId!)
            .eq('week_number', weekNumber!)
            .eq('day_number', day)
            .limit(1); // only check if at least 1 row exists

        temp[day] = (data as List).isNotEmpty; // true if logged
      } catch (e) {
        print('Exception fetching day $day: $e');
        temp[day] = false;
      }
    }

    // Determine next workout day
    int? nextDay;
    for (int day = 1; day <= 7; day++) {
      if (temp[day] == false) {
        nextDay = day;
        break;
      }
    }

    setState(() {
      completedDays = temp;
      nextWorkoutDay = nextDay;
      isLoading = false;
    });
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (programId == null || weekNumber == null) {
      return const Center(
        child: Text(
          "Select a program to get started 💪",
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _greetingCard(),
          const SizedBox(height: 16),
          _nextWorkoutCard(),
          const SizedBox(height: 16),
          _weeklyProgressCard(),
          const SizedBox(height: 16),
          _quickActionsCard(),
        ],
      ),
    );
  }

  // ---------------- UI CARDS ----------------
  Widget _greetingCard() {
    return _card(
      color: Colors.deepPurple.shade100,
      height: 80,
      child: const Center(
        child: Text(
          "Welcome back 💪 Let's get stronger today!",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _nextWorkoutCard() {
    return _card(
      color: Colors.deepPurple.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Next Workout",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (nextWorkoutDay == null)
            const Text("🎉 Week completed!")
          else ...[
            Text("Week $weekNumber - Day $nextWorkoutDay"),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/workout',
                  arguments: {
                    'programId': programId!,
                    'weekNumber': weekNumber!,
                    'dayNumber': nextWorkoutDay!,
                  },
                );
              },
              child: const Text("Start Workout"),
            )
          ],
        ],
      ),
    );
  }

  Widget _weeklyProgressCard() {
    final today = DateTime.now().weekday;

    return _card(
      color: Colors.deepPurple.shade300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "This Week",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final d = i + 1;
              final done = completedDays[d] ?? false;
              final isToday = d == today;

              Color color = done
                  ? Colors.green
                  : isToday
                  ? Colors.blue
                  : Colors.grey;

              return Column(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color,
                    child: done
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                      "$d",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_dayLabel(d), style: const TextStyle(fontSize: 12)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _quickActionsCard() {
    return _card(
      color: Colors.deepPurple.shade400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/programs'),
                icon: const Icon(Icons.fitness_center),
                label: const Text("Programs"),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.bar_chart),
                label: const Text("Progress"),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.settings),
                label: const Text("Settings"),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ---------------- Utility ----------------
  Widget _card({required Widget child, Color? color, double? height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  String _dayLabel(int d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d - 1];
  }
}
