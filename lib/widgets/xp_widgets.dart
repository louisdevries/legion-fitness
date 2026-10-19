import 'package:flutter/material.dart';
import '../services/xp_service.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

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
    final c = AppColors.of(context);
    final ink = c.onAccent;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Big level display — same lime card as the home hero
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_summary.level}',
                  style: appDisplay(context, 32, color: c.accent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Level ${_summary.level}',
                            style: appDisplay(context, 26, color: ink)),
                        const Spacer(),
                        Text(
                          '${_summary.totalXp} XP',
                          style: TextStyle(
                            color: ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppProgressBar(
                      _summary.progress,
                      height: 7,
                      color: ink,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_summary.xpForLevel - _summary.xpIntoLevel} XP to Level ${_summary.level + 1}',
                      style: TextStyle(
                        color: ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Recent activity
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Recent XP', style: appDisplay(context, 22)),
              const SizedBox(height: 4),
              if (_recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Complete workouts and goals to start earning XP.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.muted),
                  ),
                )
              else
                ..._recent.take(5).map((e) => _XpEventTile(event: e)),
            ],
          ),
        ),
      ],
    );
  }
}

class _XpEventTile extends StatelessWidget {
  final XpEvent event;
  const _XpEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = _colorForSource(event.sourceType, c);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AppIconBadge(
            _iconForSource(event.sourceType),
            size: 36,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  _formatTimeAgo(event.createdAt),
                  style: TextStyle(fontSize: 11, color: c.muted),
                ),
              ],
            ),
          ),
          Text(
            '+${event.amount}',
            style: appDisplay(context, 20, color: c.accentText),
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

  Color _colorForSource(String type, AppColors c) {
    switch (type) {
      case 'achievement':
      case 'program_complete': return c.premium;
      case 'streak': return c.warning;
      default: return c.accentText;
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