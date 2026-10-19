import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';

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
    final c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WORKOUT PROGRESS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
                color: c.muted,
              ),
            ),
            Text('$completed / $total',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),

        const SizedBox(height: 8),

        AppProgressBar(progress, height: 8),
      ],
    );
  }
}
