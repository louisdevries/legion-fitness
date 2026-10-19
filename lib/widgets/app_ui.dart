import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared building blocks for the Legion look (see the home screen).

/// Big condensed heading/number style.
TextStyle appDisplay(BuildContext context, double size, {Color? color}) =>
    TextStyle(
      fontFamily: AppTheme.displayFont,
      fontWeight: FontWeight.w800,
      fontSize: size,
      height: 1.05,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

/// Rounded card with a hairline border and no shadow. Tappable when
/// [onTap] is set.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: color ?? c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor ?? c.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Section heading ("Your week", "Programs") with optional trailing text.
class AppSectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final double size;

  const AppSectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.onTrailingTap,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(title, style: appDisplay(context, size))),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: TextStyle(
                color: onTrailingTap != null ? c.accentText : c.muted,
                fontSize: 13,
                fontWeight:
                    onTrailingTap != null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

/// Lime progress bar on a muted track.
class AppProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;

  const AppProgressBar(this.value, {super.key, this.height = 6, this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: c.track,
        valueColor: AlwaysStoppedAnimation(color ?? c.accent),
      ),
    );
  }
}

/// Small outlined or filled pill ("6 exercises", "Premium").
class AppPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final Color? color;

  const AppPill(
    this.label, {
    super.key,
    this.icon,
    this.filled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = filled ? c.onAccent : (color ?? c.accentText);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? (color ?? c.accent) : null,
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: fg.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded-square icon badge used on list rows and program cards.
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  const AppIconBadge(
    this.icon, {
    super.key,
    this.color,
    this.background,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? c.track,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color ?? c.accentText, size: size * 0.55),
    );
  }
}
