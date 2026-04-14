import 'package:flutter/material.dart';

class TimerAdjustControls extends StatelessWidget {
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const TimerAdjustControls({
    super.key,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: onMinus,
          child: const Text('-5s'),
        ),
        ElevatedButton(
          onPressed: onPlus,
          child: const Text('+5s'),
        ),
      ],
    );
  }
}