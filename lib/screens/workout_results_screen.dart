import 'package:flutter/material.dart';
import '../services/xp_service.dart';
import '../services/achievement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

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
    if (s == 0) return '$m min';
    return '$m min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Column(
                  children: [
                    const Spacer(),

                    // ── Header ─────────────────────────────────────
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 52,
                        color: c.onAccent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Workout complete', style: appDisplay(context, 40)),
                    const SizedBox(height: 6),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(fontSize: 17, color: c.muted),
                    ),

                    const SizedBox(height: 24),

                    // ── Stats row ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatChip(
                            label: 'Exercises',
                            value: '${exercises.length}',
                            icon: Icons.fitness_center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatChip(
                            label: 'Sets',
                            value: '$totalSetsCompleted',
                            icon: Icons.repeat,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Exercise list ──────────────────────────────
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < exercises.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                            _ExerciseRow(exercise: exercises[i]),
                          ],
                        ],
                      ),
                    ),

                    // ── XP / achievements ──────────────────────────
                    if (xpGrants.isNotEmpty || achievements.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        borderColor: c.premium.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final g in xpGrants)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(Icons.star_rounded,
                                        color: c.premium, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        g.isLevelUp
                                            ? '+${g.amount} XP  ·  Level ${g.newLevel}!'
                                            : '+${g.amount} XP  ·  ${g.label}',
                                        style: TextStyle(
                                          fontWeight: g.isLevelUp
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: g.isLevelUp
                                              ? c.premium
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            for (final a in achievements)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(Icons.emoji_events,
                                        color: c.premium, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Unlocked: ${a.label}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),
                    const SizedBox(height: 20),

                    // ── Done button ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
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
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AppIconBadge(icon),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: appDisplay(context, 30)),
              Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
            ],
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
    final isTimed =
        durationType.contains('second') || durationType.contains('time_max');
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            setsLabel,
            style: TextStyle(fontSize: 13, color: AppColors.of(context).muted),
          ),
        ],
      ),
    );
  }
}
