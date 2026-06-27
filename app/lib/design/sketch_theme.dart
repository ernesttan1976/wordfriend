import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SketchTheme {
  // Core colors
  static const paper = Color(0xFFFFFAF0);
  static const paperSoft = Color(0xFFFFF4DD);
  static const ink = Color(0xFF222222);
  static const mutedGray = Color(0xFF6B6B6B);

  // Muted kid-friendly accents
  static const sage = Color(0xFFA8D5BA);
  static const dustyBlue = Color(0xFFA7C7E7);
  static const warmOrange = Color(0xFFF4A261);
  static const mutedYellow = Color(0xFFE9C46A);
  static const softCoral = Color(0xFFF28482);

  // Spacing scale
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;

  static ThemeData build() {
    final baseText = GoogleFonts.nunito(
      color: ink,
      fontSize: 16,
    );

    return ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: paper,
      colorScheme: const ColorScheme.light(
        primary: sage,
        secondary: dustyBlue,
        surface: paperSoft,
        background: paper,
        error: softCoral,
        onPrimary: ink,
        onSecondary: ink,
        onSurface: ink,
        onBackground: ink,
        onError: ink,
      ),
      textTheme: TextTheme(
        bodyMedium: baseText,
        bodyLarge: baseText.copyWith(fontSize: 18),
        titleLarge: GoogleFonts.fredoka(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        headlineMedium: GoogleFonts.fredoka(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
