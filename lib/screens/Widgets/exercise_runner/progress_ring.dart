import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  final bool isTimed;
  final bool isResting;
  final int remainingSeconds;
  final int totalSeconds;
  final String quantityDisplay;

  const ProgressRing({
    super.key,
    required this.isTimed,
    required this.isResting,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.quantityDisplay,
  });

  double get _progress => totalSeconds == 0
      ? 0.0
      : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 14,
              valueColor:
              AlwaysStoppedAnimation(Colors.grey.shade300),
            ),
          ),
          if (isTimed || isResting)
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 14,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTimed || isResting
                    ? '$remainingSeconds'
                    : quantityDisplay,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isTimed || isResting ? 'seconds' : 'reps',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}