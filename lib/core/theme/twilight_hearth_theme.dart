// Twilight Hearth design tokens and ThemeData (dark-mode only), per SPEC §6.7.
//
// - Primary colors: charcoal #2D2926 (background), dusty plum #7A5E80
//   (accents), soft lilac #C8A0C8 (highlights).
// - Typography: Nunito via google_fonts.
// - Iconography: Material Symbols Outlined (loaded at call sites from
//   material_symbols_icons).
// - Rounded corners: 12dp default.
// - System dark/light setting is ignored; Twilight Hearth is always applied.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TwilightHearthColors {
  const TwilightHearthColors._();

  static const Color charcoal = Color(0xFF2D2926);
  static const Color dustyPlum = Color(0xFF7A5E80);
  static const Color softLilac = Color(0xFFC8A0C8);
}

class TwilightHearthTheme {
  const TwilightHearthTheme._();

  static const double defaultCornerRadius = 12.0;

  static ThemeData build() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: TwilightHearthColors.dustyPlum,
      brightness: Brightness.dark,
      surface: TwilightHearthColors.charcoal,
      primary: TwilightHearthColors.dustyPlum,
      secondary: TwilightHearthColors.softLilac,
    );

    final textTheme = GoogleFonts.nunitoTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: TwilightHearthColors.charcoal,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(defaultCornerRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultCornerRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(defaultCornerRadius),
          ),
        ),
      ),
    );
  }
}
