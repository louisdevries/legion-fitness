import 'dart:async';
import 'package:flutter/material.dart';
import 'exercise_runner_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExercisePreviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final int restSeconds;

  // ✅ ADD THESE
  final int programId;
  final int weekNumber;
  final int dayNumber;

  const ExercisePreviewScreen({
    super.key,
    required this.exercises,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    this.restSeconds = 60,
  });

  @override
  State<ExercisePreviewScreen> createState() => _ExercisePreviewScreenState();
}

class _ExercisePreviewScreenState extends State<ExercisePreviewScreen> {
  bool isStarting = false;
  int countdown = 5;
  Timer? countdownTimer;

  void startExerciseCountdown() {
    setState(() => isStarting = true);
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown <= 1) {
        timer.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExerciseRunnerScreen(
              exercises: widget.exercises,
              restSeconds: widget.restSeconds,

              // ✅ PASS THEM THROUGH
              programId: widget.programId,
              weekNumber: widget.weekNumber,
              dayNumber: widget.dayNumber,
            ),
          ),
        );
      } else {
        setState(() => countdown--);
      }
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isStarting) {
      return Scaffold(
        appBar: AppBar(title: const Text("Get Ready")),
        body: Center(
          child: Text(
            "$countdown",
            style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Exercises")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.exercises.length,
                itemBuilder: (context, index) {
                  final ex = widget.exercises[index];
                  final minQ = ex['min_quantity'] as int? ?? 0;
                  final maxQ = ex['max_quantity'] as int? ?? minQ;
                  final qty = ((minQ + maxQ) / 2).round();
                  final sets = ex['sets'] as int? ?? 1;
                  final durationType =
                  (ex['duration_type'] as String? ?? 'reps').toLowerCase();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: ex['media_url'] != null &&
                          ex['media_url'].toString().isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: ex['media_url'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                          : null,
                      title: Text(ex['name'] ?? 'Exercise'),
                      subtitle: Text(
                        durationType.contains('seconds')
                            ? "$sets sets × $qty sec"
                            : "$sets sets × $qty reps",
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: startExerciseCountdown,
              child: const Text("Start Exercise"),
            ),
          ],
        ),
      ),
    );
  }
}
