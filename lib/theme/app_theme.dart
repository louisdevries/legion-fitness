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

  /// Destructive actions and error snackbars. A constant so it works in
  /// const widgets; matches the coral used for [AppColors.warning].
  static const danger = Color(0xFFE5583D);

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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Buttons: lime fill + ink text, like the home "Start" button ──
      filledButtonTheme: FilledButtonThemeData(style: _accentButton(colors)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _accentButton(colors)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onBackground,
          side: BorderSide(color: colors.cardBorder, width: 1.2),
          minimumSize: const Size(0, 48),
          shape: _buttonShape,
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentText,
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: colors.muted),
        hintStyle: TextStyle(color: colors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.accentText, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.warning),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.warning, width: 1.6),
        ),
      ),

      // ── Surfaces ──
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: onBackground,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.cardBorder),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.muted,
        subtitleTextStyle: TextStyle(color: colors.muted, fontSize: 13),
      ),

      // ── Selection controls ──
      tabBarTheme: TabBarThemeData(
        labelColor: onBackground,
        unselectedLabelColor: colors.muted,
        indicatorColor: colors.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: colors.cardBorder,
        labelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.card,
        selectedColor: colors.accent,
        side: BorderSide(color: colors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w600,
          color: onBackground,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
          color: colors.onAccent,
        ),
        checkmarkColor: colors.onAccent,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? colors.accent : colors.card),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? colors.onAccent : onBackground),
          side: WidgetStatePropertyAll(BorderSide(color: colors.cardBorder)),
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
          )),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.onAccent : colors.muted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.accent : colors.track),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.accent : colors.cardBorder),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.accent : null),
        checkColor: WidgetStatePropertyAll(colors.onAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.accentText : colors.muted),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accent,
        inactiveTrackColor: colors.track,
        thumbColor: colors.accent,
        overlayColor: colors.accent.withValues(alpha: 0.15),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        headerHeadlineStyle: const TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          fontSize: 30,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.accent : null),
        dayForegroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.onAccent : null),
        todayBorder: BorderSide(color: colors.accentText),
        todayForegroundColor: WidgetStatePropertyAll(colors.accentText),
        confirmButtonStyle:
            TextButton.styleFrom(foregroundColor: colors.accentText),
        cancelButtonStyle:
            TextButton.styleFrom(foregroundColor: colors.muted),
      ),
    );
  }

  static final _buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  static ButtonStyle _accentButton(AppColors colors) => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? colors.track : colors.accent),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? colors.muted : colors.onAccent),
        overlayColor:
            WidgetStatePropertyAll(colors.onAccent.withValues(alpha: 0.08)),
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        shape: WidgetStatePropertyAll(_buttonShape),
        textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        )),
      );
}
