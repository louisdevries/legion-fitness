import 'package:flutter/material.dart';

/// Compact horizontal pill timer used during exercises.
///
/// Bundles its timer adjustment controls (-5s / +5s) inside the pill
/// instead of having them as a separate row below. Count-up (time_max)
/// exercises hide the adjust controls and the "/ Ns" target label since
/// there's no fixed target to adjust against.
class ProgressRing extends StatelessWidget {
  final bool isTimed;
  final bool isResting;
  final bool isPaused;
  final int remainingSeconds;
  final int totalSeconds;
  final String quantityDisplay;
  final VoidCallback? onTogglePause;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  /// When true, the timer counts up from 0 to [totalSeconds] instead of
  /// down from [totalSeconds] to 0. Underlying completion mechanics
  /// (auto-finish, ding, +/-5s adjust) are unchanged — only the displayed
  /// number and progress bar direction flip.
  final bool countUp;

  /// What was actually logged last week for this exact set, e.g. "47s"
  /// or "12 reps" — shown as a small "beat it" caption below the bar.
  /// Null when there's no prior week to compare against.
  final String? previousLabel;

  const ProgressRing({
    super.key,
    required this.isTimed,
    required this.isResting,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.quantityDisplay,
    this.isPaused = false,
    this.onTogglePause,
    this.onMinus,
    this.onPlus,
    this.countUp = false,
    this.previousLabel,
  });

  int get _displaySeconds =>
      countUp ? (totalSeconds - remainingSeconds) : remainingSeconds;

  double get _progress {
    if (totalSeconds == 0) return 1.0;
    if (countUp) {
      return ((totalSeconds - remainingSeconds) / totalSeconds)
          .clamp(0.0, 1.0);
    }
    return (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final showTime = isTimed || isResting;
    final accent = isPaused
        ? Colors.orange
        : (isResting ? Colors.green : cs.primary);

    final canPause = showTime && onTogglePause != null;
    final canAdjust = showTime && onMinus != null && onPlus != null && !countUp;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaused
              ? Colors.orange.withValues(alpha: 0.5)
              : cs.onSurface.withValues(alpha: 0.08),
          width: isPaused ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  showTime ? Icons.timer_outlined : Icons.repeat,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          showTime ? '$_displaySeconds' : quantityDisplay,
                          style: TextStyle(
                            fontSize: showTime
                                ? 36
                                : (quantityDisplay.length > 4 ? 22 : 36),
                            height: 1.0,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (showTime && totalSeconds > 0 && !countUp) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '/ ${totalSeconds}s',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaused
                          ? 'paused'
                          : showTime
                          ? (isResting ? 'rest' : 'seconds')
                          : 'reps',
                      style: TextStyle(
                        fontSize: 12,
                        color: isPaused
                            ? Colors.orange
                            : cs.onSurface.withValues(alpha: 0.6),
                        fontWeight:
                        isPaused ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (canAdjust) ...[
                _PillButton(
                  label: '-5s',
                  accent: accent,
                  onTap: onMinus!,
                ),
                const SizedBox(width: 6),
                _PillButton(
                  label: '+5s',
                  accent: accent,
                  onTap: onPlus!,
                ),
                const SizedBox(width: 6),
              ],
              if (canPause)
                Material(
                  color: accent.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTogglePause,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        color: accent,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: showTime ? _progress : 1.0,
              minHeight: 6,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          if (previousLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 14, color: cs.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(
                  'Previous: $previousLabel — beat it!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Larger circular timer used on the rest screen specifically.
/// Shows the countdown big and central, with controls (pause / -5 / +5)
/// underneath.
class ProgressRingCircle extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final bool isPaused;
  final VoidCallback? onTogglePause;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const ProgressRingCircle({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.isPaused = false,
    this.onTogglePause,
    this.onMinus,
    this.onPlus,
  });

  double get _progress {
    if (totalSeconds == 0) return 1.0;
    return (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = isPaused ? Colors.orange : Colors.green;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 12,
                  valueColor: AlwaysStoppedAnimation(
                      cs.onSurface.withValues(alpha: 0.08)),
                ),
              ),
              SizedBox(
                width: 220,
                height: 220,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 12,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$remainingSeconds',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPaused ? 'paused' : 'seconds',
                    style: TextStyle(
                      fontSize: 14,
                      color: isPaused
                          ? Colors.orange
                          : cs.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onMinus != null)
              _PillButton(
                label: '-5s',
                accent: accent,
                onTap: onMinus!,
              ),
            if (onTogglePause != null) ...[
              const SizedBox(width: 12),
              Material(
                color: accent.withValues(alpha: 0.12),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTogglePause,
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    child: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      color: accent,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (onPlus != null)
              _PillButton(
                label: '+5s',
                accent: accent,
                onTap: onPlus!,
              ),
          ],
        ),
      ],
    );
  }
}