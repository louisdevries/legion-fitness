import 'package:flutter/material.dart';

class RestControls extends StatelessWidget {
  final VoidCallback onSkip;

  const RestControls({super.key, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: onSkip,
          icon: const Icon(Icons.skip_next),
          label: const Text('Skip Rest'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}