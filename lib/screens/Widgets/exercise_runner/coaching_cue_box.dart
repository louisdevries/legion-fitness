import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CoachingCueBox extends StatelessWidget {
  final String cues;

  const CoachingCueBox({super.key, required this.cues});

  @override
  Widget build(BuildContext context) {
    if (cues.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: c.accent, width: 4),
          top: BorderSide(color: c.cardBorder),
          right: BorderSide(color: c.cardBorder),
          bottom: BorderSide(color: c.cardBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates, color: c.accentText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cues,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
