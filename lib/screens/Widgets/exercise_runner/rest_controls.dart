import 'package:flutter/material.dart';

class RestControls extends StatelessWidget {
  final VoidCallback onSkip;

  const RestControls({super.key, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        OutlinedButton.icon(
          onPressed: onSkip,
          icon: const Icon(Icons.skip_next_rounded),
          label: const Text('Skip rest'),
        ),
      ],
    );
  }
}
