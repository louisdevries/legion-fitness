import 'package:flutter/material.dart';

class WorkoutProgressBar extends StatelessWidget {
  final int completed;
  final int total;

  const WorkoutProgressBar({
    super.key,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Workout Progress',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('$completed / $total'),
          ],
        ),

        const SizedBox(height: 6),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }
}