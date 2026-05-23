import 'package:flutter/material.dart';
import '../services/xp_service.dart';

// =====================================================================
// HomeXpBanner — compact level pill for the home screen top
// =====================================================================

class HomeXpBanner extends StatelessWidget {
  final XpSummary summary;
  final VoidCallback? onTap;

  const HomeXpBanner({
    super.key,
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${summary.level}',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Level ${summary.level}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${summary.xpIntoLevel} / ${summary.xpForLevel} XP',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: summary.progress,
                      minHeight: 5,
                      backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ProfileXpSection — full breakdown for the profile screen
// =====================================================================

class ProfileXpSection extends StatefulWidget {
  const ProfileXpSection({super.key});

  @override
  State<ProfileXpSection> createState() => _ProfileXpSectionState();
}

class _ProfileXpSectionState extends State<ProfileXpSection> {
  XpSummary _summary = const XpSummary.empty();
  List<XpEvent> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await XpService.fetchSummary();
    final r = await XpService.fetchRecent(limit: 8);
    if (!mounted) return;
    setState(() {
      _summary = s;
      _recent = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Big level display
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.onPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_summary.level}',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${_summary.level}',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_summary.totalXp} total XP',
                      style: TextStyle(
                        color: cs.onPrimary.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _summary.progress,
                        minHeight: 6,
                        backgroundColor:
                        cs.onPrimary.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(cs.onPrimary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_summary.xpIntoLevel} / ${_summary.xpForLevel} XP to Level ${_summary.level + 1}',
                      style: TextStyle(
                        color: cs.onPrimary.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Recent activity
        const Text(
          'Recent XP',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (_recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Complete workouts and goals to start earning XP.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          )
        else
          ..._recent.map((e) => _XpEventTile(event: e)),
      ],
    );
  }
}

class _XpEventTile extends StatelessWidget {
  final XpEvent event;
  const _XpEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _colorForSource(event.sourceType, cs)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForSource(event.sourceType),
              color: _colorForSource(event.sourceType, cs),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  _formatTimeAgo(event.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${event.amount}',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForSource(String type) {
    switch (type) {
      case 'workout': return Icons.fitness_center;
      case 'steps_daily': return Icons.directions_walk;
      case 'run':
      case 'run_5km': return Icons.directions_run;
      case 'achievement': return Icons.emoji_events;
      case 'program_complete': return Icons.workspace_premium;
      case 'streak': return Icons.local_fire_department;
      default: return Icons.star;
    }
  }

  Color _colorForSource(String type, ColorScheme cs) {
    switch (type) {
      case 'workout': return cs.primary;
      case 'steps_daily': return Colors.teal;
      case 'run':
      case 'run_5km': return Colors.green;
      case 'achievement': return Colors.amber;
      case 'program_complete': return Colors.purple;
      case 'streak': return Colors.deepOrange;
      default: return cs.primary;
    }
  }

  String _formatTimeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}