import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/progress_service.dart';

class ExercisesScreen extends StatefulWidget {
  final int programId;
  final int weekNumber;
  final int dayNumber;
  final List<Exercise> exercises;

  const ExercisesScreen({
    super.key,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    required this.exercises,
  });

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  int currentIndex = 0;
  bool isCompleted = false;

  void _markCompleted() async {
    final exercise = widget.exercises[currentIndex];

    // TEMP: Log 0 reps for now (you can add input later)
    await ProgressService.logExercise(
      programId: widget.programId,
      exerciseId: exercise.id,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
      repsCompleted: 0,
    );

    setState(() {
      isCompleted = true;
    });

    // Move to next exercise or finish
    if (currentIndex < widget.exercises.length - 1) {
      setState(() {
        currentIndex++;
        isCompleted = false;
      });
    } else {
      // Finished all exercises
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Day Complete!"),
          content: const Text("You finished all exercises for this day."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercises[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text("Week ${widget.weekNumber} - Day ${widget.dayNumber}"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Exercise Name
            Text(
              exercise.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Exercise Media
            exercise.mediaUrl != null && exercise.mediaUrl!.isNotEmpty
                ? Image.network(exercise.mediaUrl!, height: 200)
                : Container(
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: Text("Media goes here")),
            ),

            const SizedBox(height: 16),

            // Coaching cues
            Text(
              exercise.coachingCues ?? 'No cues provided',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCompleted ? null : _markCompleted,
                child: Text(isCompleted ? "Completed" : "Mark as Complete"),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              "${currentIndex + 1} of ${widget.exercises.length}",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
