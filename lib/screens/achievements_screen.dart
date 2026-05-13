import 'package:flutter/material.dart';
import '../services/achievement_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Future<List<AchievementRow>>? _future;

  @override
  void initState() {
    super.initState();
    _future = AchievementService.fetchAll();
  }

  Future<void> _refresh() async {
    setState(() => _future = AchievementService.fetchAll());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: FutureBuilder<List<AchievementRow>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snap.data!;
          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Start working out to unlock achievements!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          final inProgress =
          all.where((a) => a.status == AchievementStatus.inProgress).toList()
            ..sort((a, b) => b.progress.compareTo(a.progress));
          final completed =
          all.where((a) => a.status == AchievementStatus.completed).toList()
            ..sort(
                  (a, b) => (b.unlockedAt ?? DateTime(0))
                  .compareTo(a.unlockedAt ?? DateTime(0)),
            );
          final locked =
          all.where((a) => a.status == AchievementStatus.locked).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _SummaryHeader(
                  completedCount: completed.length,
                  totalCount: all.length,
                ),
                const SizedBox(height: 16),

                if (inProgress.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'In Progress',
                    count: inProgress.length,
                    icon: Icons.bolt,
                  ),
                  const SizedBox(height: 8),
                  ...inProgress.map((a) => _AchievementCard(achievement: a)),
                  const SizedBox(height: 24),
                ],

                if (completed.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Completed',
                    count: completed.length,
                    icon: Icons.emoji_events,
                  ),
                  const SizedBox(height: 8),
                  ...completed.map((a) => _AchievementCard(achievement: a)),
                  const SizedBox(height: 24),
                ],

                if (locked.isNotEmpty)
                  _LockedSection(rows: locked),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =====================================================================
// Summary header
// =====================================================================

class _SummaryHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;

  const _SummaryHeader({
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: cs.primary, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completedCount of $totalCount unlocked',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Section header
// =====================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Achievement card
// =====================================================================

class _AchievementCard extends StatelessWidget {
  final AchievementRow achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = achievement.status == AchievementStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(
          color: isCompleted
              ? cs.primary.withValues(alpha: 0.5)
              : cs.onSurface.withValues(alpha: 0.08),
          width: isCompleted ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isCompleted ? cs.primary : cs.onSurface)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFromName(achievement.icon),
              color: isCompleted
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _TierBadge(tier: achievement.tier),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: achievement.progress,
                          minHeight: 5,
                          backgroundColor:
                          cs.onSurface.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(
                            isCompleted ? cs.primary : cs.tertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${achievement.currentValue} / ${achievement.targetValue}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFromName(String? name) {
    switch (name) {
      case 'directions_walk':
        return Icons.directions_walk;
      case 'directions_run':
        return Icons.directions_run;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'fitness_center':
        return Icons.fitness_center;
      default:
        return Icons.emoji_events;
    }
  }
}

class _TierBadge extends StatelessWidget {
  final int tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.grey,        // 1 Novice
      Colors.brown,       // 2 Apprentice
      Colors.blueGrey,    // 3 Adept
      Colors.orange,      // 4 Master
      Colors.amber.shade700, // 5 Grandmaster
    ];
    final labels = ['I', 'II', 'III', 'IV', 'V'];
    final color = colors[(tier - 1).clamp(0, colors.length - 1)];
    final label = labels[(tier - 1).clamp(0, labels.length - 1)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

// =====================================================================
// Locked section — collapsed by default, expandable
// =====================================================================

class _LockedSection extends StatefulWidget {
  final List<AchievementRow> rows;
  const _LockedSection({required this.rows});

  @override
  State<_LockedSection> createState() => _LockedSectionState();
}

class _LockedSectionState extends State<_LockedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 20, color: cs.onSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                const Text(
                  'Locked',
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.rows.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          ...widget.rows.map((a) => _LockedTile(achievement: a)),
        ],
      ],
    );
  }
}

class _LockedTile extends StatelessWidget {
  final AchievementRow achievement;
  const _LockedTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.5),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline,
              size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _TierBadge(tier: achievement.tier),
        ],
      ),
    );
  }
}