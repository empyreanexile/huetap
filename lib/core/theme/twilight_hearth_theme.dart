// Twilight Hearth design tokens and ThemeData (light variant).
//
// Deviates from SPEC §6.7 which specifies "dark mode only". The spec itself
// leaves a door open: "v1.x will revisit with a light variant if issue volume
// warrants it." This file implements that light variant early so the UI
// matches the approved v4 wireframes. Revisit the spec's §6.7 wording before
// v1.0 lock.
//
// Token set mirrors the wireframes' `:root` CSS variables 1:1:
//   - Core palette: charcoal, plum (+ plumDeep), lilac, rose, meadow, blue,
//     amber, danger.
//   - Surfaces: cream / creamAlt / creamDeep (ordered light → warm).
//   - Text hierarchy: text / text2 / text3 / text4.
//   - Dividers, gradients, radii, shadows.
// Typography is Nunito via google_fonts, matching SPEC §6.7.
//
// Widgets that need non-Material-standard visuals (gradient fills on buttons,
// radial scaffold backgrounds, custom elevation recipes) should pull from
// `TwilightHearthGradients`, `TwilightHearthShadows`, and `TwilightHearthRadii`
// directly. ThemeData covers only what the Material widgets consume.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TwilightHearthColors {
  const TwilightHearthColors._();

  // Core palette -------------------------------------------------------------
  static const Color charcoal = Color(0xFF2D2926);
  static const Color plum = Color(0xFF7A5E80);
  static const Color plumDeep = Color(0xFF5F4864);
  static const Color lilac = Color(0xFFC8A0C8);
  static const Color rose = Color(0xFFD4A088);
  static const Color meadow = Color(0xFFA3C9A0);
  static const Color blue = Color(0xFF9EB8D4);
  static const Color amber = Color(0xFFD4BA8A);
  static const Color danger = Color(0xFFC45B4F);

  // Backwards-compatible alias for pre-wireframe consumers.
  static const Color dustyPlum = plum;
  static const Color softLilac = lilac;

  // Surfaces -----------------------------------------------------------------
  static const Color cream = Color(0xFFFFF8F2);
  static const Color creamAlt = Color(0xFFFFFCF7);
  static const Color creamDeep = Color(0xFFF5ECE0);

  // Text hierarchy -----------------------------------------------------------
  static const Color text = Color(0xFF2D2926);
  static const Color text2 = Color(0xFF8A7F76);
  static const Color text3 = Color(0xFFB5ADA5);
  static const Color text4 = Color(0xFFD4CCC3);

  // Dividers -----------------------------------------------------------------
  static const Color divider = Color(0x142D2926); // ~0.08 alpha on charcoal
  static const Color dividerStrong = Color(0x242D2926); // ~0.14 alpha
}

class TwilightHearthRadii {
  const TwilightHearthRadii._();

  static const double card = 20;
  static const double hero = 22;
  static const double button = 14;
  static const double input = 12;
  static const double chip = 20;
  static const double tag = 8;
}

class TwilightHearthShadows {
  const TwilightHearthShadows._();

  // shadow-card: subtle lift for list/card items.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0D7A5E80), // rgba(122,94,128,0.05)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color(0x127A5E80), // rgba(122,94,128,0.07)
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
  ];

  // shadow-elev: modal / hero-card elevation.
  static const List<BoxShadow> elev = <BoxShadow>[
    BoxShadow(
      color: Color(0x147A5E80), // rgba(122,94,128,0.08)
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
    BoxShadow(
      color: Color(0x1A2D2926), // rgba(45,41,38,0.10)
      offset: Offset(0, 16),
      blurRadius: 36,
    ),
  ];

  // shadow-fab: prominent floating action button.
  static const List<BoxShadow> fab = <BoxShadow>[
    BoxShadow(
      color: Color(0x472D2926), // rgba(45,41,38,0.28)
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
    BoxShadow(
      color: Color(0x2E7A5E80), // rgba(122,94,128,0.18)
      offset: Offset(0, 16),
      blurRadius: 34,
    ),
  ];
}

class TwilightHearthGradients {
  const TwilightHearthGradients._();

  // 135deg: plum → plum-light → lilac. For primary chips, progress, accents.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: <double>[0.0, 0.6, 1.0],
    colors: <Color>[Color(0xFF7A5E80), Color(0xFFA285A8), Color(0xFFC8A0C8)],
  );

  // 135deg: charcoal → plum-deep → plum. For FAB, primary button, brand dot.
  static const LinearGradient charcoal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: <double>[0.0, 0.6, 1.0],
    colors: <Color>[Color(0xFF2D2926), Color(0xFF5F4864), Color(0xFF7A5E80)],
  );

  // 145deg: cream-alt → warm cream. For hero cards.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment(-0.6, -1.0),
    end: Alignment(0.6, 1.0),
    colors: <Color>[Color(0xFFFFFCF7), Color(0xFFFFF4E8)],
  );

  // Radial cream body: applied on the root scaffold via a Container decoration
  // rather than through ThemeData.scaffoldBackgroundColor (which accepts solid
  // colors only). `scaffoldBackgroundColor` is set to `creamDeep` as a fallback.
  static const RadialGradient scaffoldBody = RadialGradient(
    center: Alignment(0, -1),
    radius: 1.4,
    stops: <double>[0.0, 0.55, 1.0],
    colors: <Color>[Color(0xFFF5ECE0), Color(0xFFEBDFCC), Color(0xFFE0D2B8)],
  );

  // 180deg charcoal overlay for modal scrims.
  static const LinearGradient overlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xBF2D2926), // rgba(45,41,38,0.75)
      Color(0xEB2D2926), // rgba(45,41,38,0.92)
    ],
  );
}

class TwilightHearthTheme {
  const TwilightHearthTheme._();

  // Kept for backwards compatibility with earlier scaffolding. Prefer
  // `TwilightHearthRadii.input` (12) or `.button` (14) in new code.
  static const double defaultCornerRadius = 12.0;

  static ThemeData build() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: TwilightHearthColors.plum,
      brightness: Brightness.light,
      primary: TwilightHearthColors.plum,
      onPrimary: Colors.white,
      secondary: TwilightHearthColors.lilac,
      onSecondary: TwilightHearthColors.charcoal,
      tertiary: TwilightHearthColors.rose,
      error: TwilightHearthColors.danger,
      surface: TwilightHearthColors.cream,
      onSurface: TwilightHearthColors.text,
      surfaceContainerHighest: TwilightHearthColors.creamAlt,
      outline: TwilightHearthColors.dividerStrong,
      outlineVariant: TwilightHearthColors.divider,
    );

    final TextTheme textTheme =
        GoogleFonts.nunitoTextTheme(
          ThemeData(brightness: Brightness.light).textTheme,
        ).apply(
          bodyColor: TwilightHearthColors.text,
          displayColor: TwilightHearthColors.text,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: TwilightHearthColors.creamDeep,
      canvasColor: TwilightHearthColors.cream,
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: TwilightHearthColors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: TwilightHearthColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: TwilightHearthColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: TwilightHearthColors.creamAlt,
        surfaceTintColor: Colors.transparent,
        shadowColor: TwilightHearthColors.plum.withValues(alpha: 0.18),
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwilightHearthRadii.card),
          side: const BorderSide(color: TwilightHearthColors.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TwilightHearthColors.creamAlt,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: TwilightHearthColors.text3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwilightHearthRadii.input),
          borderSide: const BorderSide(color: TwilightHearthColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwilightHearthRadii.input),
          borderSide: const BorderSide(color: TwilightHearthColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwilightHearthRadii.input),
          borderSide: const BorderSide(
            color: TwilightHearthColors.plum,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TwilightHearthColors.charcoal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwilightHearthRadii.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TwilightHearthColors.plum,
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TwilightHearthColors.plum,
          side: const BorderSide(color: TwilightHearthColors.dividerStrong),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwilightHearthRadii.button),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TwilightHearthColors.plum.withValues(alpha: 0.08),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: TwilightHearthColors.text2,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwilightHearthRadii.chip),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TwilightHearthColors.charcoal,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TwilightHearthColors.charcoal,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwilightHearthRadii.button),
        ),
      ),
    );
  }
}
