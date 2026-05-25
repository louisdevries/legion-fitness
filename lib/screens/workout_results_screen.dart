import 'package:flutter/material.dart';
import '../services/xp_service.dart';
import '../services/achievement_service.dart';

class WorkoutResultsScreen extends StatelessWidget {
  final Duration duration;
  final List<Map<String, dynamic>> exercises;
  final int totalSetsCompleted;
  final List<XpGrant> xpGrants;
  final List<UnlockedAchievement> achievements;

  const WorkoutResultsScreen({
    super.key,
    required this.duration,
    required this.exercises,
    required this.totalSetsCompleted,
    required this.xpGrants,
    required this.achievements,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m} min';
    return '${m} min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    const Spacer(),

                    // ── Header ─────────────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 48,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Workout Complete',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Stats row ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatChip(
                          label: 'Exercises',
                          value: '${exercises.length}',
                          icon: Icons.fitness_center,
                        ),
                        _StatChip(
                          label: 'Sets',
                          value: '$totalSetsCompleted',
                          icon: Icons.repeat,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Exercise list ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < exercises.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: cs.outlineVariant.withOpacity(0.4),
                              ),
                            _ExerciseRow(exercise: exercises[i]),
                          ],
                        ],
                      ),
                    ),

                    // ── XP / achievements ──────────────────────────
                    if (xpGrants.isNotEmpty || achievements.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final g in xpGrants)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.star_rounded,
                                        color: Colors.amber.shade600,
                                        size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      g.isLevelUp
                                          ? '+${g.amount} XP  ·  Level ${g.newLevel}!'
                                          : '+${g.amount} XP  ·  ${g.label}',
                                      style: TextStyle(
                                        fontWeight: g.isLevelUp
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: g.isLevelUp
                                            ? Colors.amber.shade800
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            for (final a in achievements)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.emoji_events,
                                        color: Colors.amber, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Unlocked: ${a.label}'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    // ── Done button ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Done', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: cs.primary, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const _ExerciseRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] as String? ?? 'Exercise';
    final sets = (exercise['sets'] as int?) ?? 1;
    final durationType =
        (exercise['duration_type'] as String? ?? 'reps').toLowerCase();
    final isTimed = durationType.contains('second');
    final qty = (exercise['min_quantity'] as int?) ?? 0;
    final setQuantities = exercise['set_quantities'];

    String setsLabel;
    if (setQuantities is List &&
        setQuantities.isNotEmpty &&
        setQuantities.any((v) => (v as num).toInt() > 0)) {
      final unit = isTimed ? 's' : ' reps';
      setsLabel = '$sets × ${setQuantities.map((v) => v.toString()).join('/')}$unit';
    } else if (durationType.contains('failure')) {
      setsLabel = '$sets × until failure';
    } else {
      final unit = isTimed ? 's' : ' reps';
      setsLabel = '$sets × $qty$unit';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            setsLabel,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
