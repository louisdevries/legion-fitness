import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

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
    final c = AppColors.of(context);
    final ink = c.onAccent;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.emoji_events, color: c.accent, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$completedCount'),
                    TextSpan(
                      text: ' / $totalCount unlocked',
                      style: const TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                  style: appDisplay(context, 32, color: ink),
                ),
                const SizedBox(height: 8),
                AppProgressBar(progress, height: 7, color: ink),
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
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.accentText),
          const SizedBox(width: 8),
          Text(title, style: appDisplay(context, 24)),
          const SizedBox(width: 8),
          AppPill('$count', filled: true),
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
    final c = AppColors.of(context);
    final isCompleted = achievement.status == AchievementStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(
          color: isCompleted ? c.accent.withValues(alpha: 0.6) : c.cardBorder,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          AppIconBadge(
            _iconFromName(achievement.icon),
            size: 46,
            color: isCompleted ? c.onAccent : c.accentText,
            background: isCompleted ? c.accent : null,
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
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _TierBadge(tier: achievement.tier),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(fontSize: 12, color: c.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppProgressBar(achievement.progress, height: 5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${achievement.currentValue} / ${achievement.targetValue}',
                      style: TextStyle(
                        fontSize: 11,
                        color: c.muted,
                        fontWeight: FontWeight.w700,
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
    final c = AppColors.of(context);
    final colors = [
      c.muted,                                   // 1 Novice
      const Color(0xFFB08968),                   // 2 Apprentice (bronze)
      const Color(0xFF9FB3C8),                   // 3 Adept (silver)
      c.accentText,                              // 4 Master
      c.premium,                                 // 5 Grandmaster (gold)
    ];
    final labels = ['I', 'II', 'III', 'IV', 'V'];
    final color = colors[(tier - 1).clamp(0, colors.length - 1)];
    final label = labels[(tier - 1).clamp(0, labels.length - 1)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
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
                    size: 20, color: AppColors.of(context).muted),
                const SizedBox(width: 8),
                Text('Locked', style: appDisplay(context, 24)),
                const SizedBox(width: 8),
                AppPill('${widget.rows.length}',
                    color: AppColors.of(context).muted),
                const Spacer(),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.of(context).muted),
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
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.6),
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(16),
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