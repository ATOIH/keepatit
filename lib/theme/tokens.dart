// Obsidian Precision design tokens — normative source:
// "Designs - keep_at_it_habit_notifier/obsidian_precision/DESIGN.md" (PRD Appendix A).
// Do not invent values here; every constant traces to that file.
import 'package:flutter/material.dart';

abstract final class KColors {
  static const Color pureBlack = Color(0xFF000000); // canvas
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF121212); // cards / containers
  static const Color surfaceHover = Color(0xFF1E1E1E); // tier 2 / active
  static const Color borderSubtle = Color(0xFF2A2A2A); // 1px ghost outlines
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A); // chips
  static const Color surfaceContainerHighest = Color(0xFF353535);
  static const Color crimson = Color(0xFFDC143C); // the single action color
  static const Color primaryTint = Color(0xFFFFB3B3); // lighter crimson (small text states)
  static const Color onSurface = Color(0xFFE2E2E2);
  static const Color lowContrast = Color(0xFF888888);
  static const Color error = Color(0xFFFFB4AB);
}

abstract final class KSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 32;
  static const double xl = 64;
  static const double gutter = 24;
  static const double marginMobile = 16;
}

/// Single radius across the system (PRD Appendix A): 4px.
const double kRadius = 4;

abstract final class KType {
  static const String grotesk = 'HankenGrotesk';
  static const String mono = 'JetBrainsMono';

  static TextStyle _g(double size, double weight,
          {double height = 1.2, double letterEm = 0}) =>
      TextStyle(
        fontFamily: grotesk,
        fontSize: size,
        height: height,
        letterSpacing: letterEm * size,
        fontWeight: _closestWeight(weight),
        fontVariations: [FontVariation('wght', weight)],
        color: KColors.onSurface,
      );

  static FontWeight _closestWeight(double w) => switch (w) {
        >= 750 => FontWeight.w800,
        >= 650 => FontWeight.w700,
        >= 550 => FontWeight.w600,
        >= 450 => FontWeight.w500,
        _ => FontWeight.w400,
      };

  static final TextStyle displayXl = _g(64, 800, height: 1.1, letterEm: -0.03);
  static final TextStyle headlineLg = _g(32, 700, letterEm: -0.01);
  static final TextStyle headlineLgMobile = _g(28, 700, letterEm: -0.01);
  static final TextStyle headlineMd = _g(20, 600, height: 1.4);
  static final TextStyle bodyLg = _g(16, 400, height: 1.6, letterEm: 0.01);
  static final TextStyle bodySm = _g(14, 400, height: 1.5, letterEm: 0.01);

  static const TextStyle labelMono = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    height: 1,
    letterSpacing: 0.6, // 0.05em * 12
    fontWeight: FontWeight.w500,
    color: KColors.onSurface,
  );

  static final TextStyle labelCaps = _g(11, 700, height: 1, letterEm: 0.12)
      .copyWith(color: KColors.lowContrast);
}

ThemeData buildKeepAtItTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: KColors.pureBlack,
    fontFamily: KType.grotesk,
    colorScheme: const ColorScheme.dark(
      primary: KColors.crimson,
      onPrimary: Colors.white,
      surface: KColors.surface,
      onSurface: KColors.onSurface,
      error: KColors.error,
      outline: KColors.borderSubtle,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: KType.displayXl,
      headlineLarge: KType.headlineLg,
      headlineMedium: KType.headlineLgMobile,
      titleMedium: KType.headlineMd,
      bodyLarge: KType.bodyLg,
      bodyMedium: KType.bodySm,
      labelSmall: KType.labelCaps,
    ),
    dividerColor: KColors.borderSubtle,
    splashFactory: NoSplash.splashFactory,
  );
}
