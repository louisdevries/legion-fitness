import 'package:flutter/material.dart';

/// Brand colours that don't map cleanly onto a Material [ColorScheme].
///
/// Lime works as a fill in both modes, but it's unreadable as text or an
/// icon on a light background — so [accentText] is lime in dark mode and a
/// dark olive in light mode. Use [accent] for fills, [accentText] for
/// foreground.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color accent; // lime fill: hero card, progress, checks
  final Color onAccent; // text/icons on a lime fill
  final Color accentText; // lime-ish foreground readable on the surface
  final Color card; // card background
  final Color cardBorder;
  final Color muted; // secondary text
  final Color track; // empty part of progress bars
  final Color premium; // crown / premium gold
  final Color warning; // coral, e.g. calories over target

  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.card,
    required this.cardBorder,
    required this.muted,
    required this.track,
    required this.premium,
    required this.warning,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? card,
    Color? cardBorder,
    Color? muted,
    Color? track,
    Color? premium,
    Color? warning,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentText: accentText ?? this.accentText,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      muted: muted ?? this.muted,
      track: track ?? this.track,
      premium: premium ?? this.premium,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      track: Color.lerp(track, other.track, t)!,
      premium: Color.lerp(premium, other.premium, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

class AppTheme {
  static const _lime = Color(0xFFC8F135);
  static const _ink = Color(0xFF0E1015);
  static const _olive = Color(0xFF4A6400);

  static const displayFont = 'Barlow Condensed';
  static const bodyFont = 'Manrope';

  static const _darkColors = AppColors(
    accent: _lime,
    onAccent: _ink,
    accentText: _lime,
    card: Color(0xFF181B22),
    cardBorder: Color(0xFF232731),
    muted: Color(0xFF8B919C),
    track: Color(0xFF2B303A),
    premium: Color(0xFFE2B04A),
    warning: Color(0xFFF08A73),
  );

  static const _lightColors = AppColors(
    accent: _lime,
    onAccent: _ink,
    accentText: _olive,
    card: Colors.white,
    cardBorder: Color(0xFFE4E6DF),
    muted: Color(0xFF666B73),
    track: Color(0xFFE6E8E1),
    premium: Color(0xFFB07D12),
    warning: Color(0xFFD9573B),
  );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        colors: _darkColors,
        background: _ink,
        onBackground: Colors.white,
        primary: _lime,
        onPrimary: _ink,
        surfaceHigh: const Color(0xFF20242C),
        surfaceHighest: const Color(0xFF282C35),
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        colors: _lightColors,
        background: const Color(0xFFF4F5F0),
        onBackground: _ink,
        primary: _olive,
        onPrimary: Colors.white,
        surfaceHigh: const Color(0xFFECEEE7),
        surfaceHighest: const Color(0xFFE4E6DF),
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppColors colors,
    required Color background,
    required Color onBackground,
    required Color primary,
    required Color onPrimary,
    required Color surfaceHigh,
    required Color surfaceHighest,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _lime,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: _lime,
      onPrimaryContainer: _ink,
      secondary: primary,
      onSecondary: onPrimary,
      error: colors.warning,
      surface: colors.card,
      onSurface: onBackground,
      onSurfaceVariant: colors.muted,
      surfaceContainerLowest: background,
      surfaceContainerLow: colors.card,
      surfaceContainer: colors.card,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      outline: colors.muted,
      outlineVariant: colors.cardBorder,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: bodyFont,
    );

    TextStyle? display(TextStyle? s) => s?.copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        );

    final text = base.textTheme;
    return base.copyWith(
      scaffoldBackgroundColor: background,
      extensions: [colors],
      textTheme: text.copyWith(
        displayLarge: display(text.displayLarge),
        displayMedium: display(text.displayMedium),
        displaySmall: display(text.displaySmall),
        headlineLarge: display(text.headlineLarge),
        headlineMedium: display(text.headlineMedium),
        headlineSmall: display(text.headlineSmall),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: onBackground,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.cardBorder),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF14171D)
            : Colors.white,
        selectedItemColor: colors.accentText,
        unselectedItemColor: colors.muted,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: DividerThemeData(color: colors.cardBorder, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brightness == Brightness.dark ? _lime : _olive,
        linearTrackColor: colors.track,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
