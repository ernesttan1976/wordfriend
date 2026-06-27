import 'package:flutter/material.dart';

class SketchTheme {
  static const _paperPrimary = Color(0xFFFFFAF0);
  static const _paperSecondary = Color(0xFFFFF7E8);
  static const _ink = Color(0xFF222222);
  static const _softGray = Color(0xFF666666);

  static ThemeData pony() {
    // Pink + soft rainbow accents
    const primaryPink = Color(0xFFFF9ECF);

    return _baseTheme(
      accentColors: const [
        primaryPink,
        Color(0xFFFFC1E3),
        Color(0xFFB5EAD7),
        Color(0xFFC7CEEA),
        Color(0xFFFFDAC1),
      ],
      primary: primaryPink,
    );
  }

  static ThemeData lego() {
    // Classic Lego-inspired colors
    const legoRed = Color(0xFFD32F2F);

    return _baseTheme(
      accentColors: const [
        legoRed,
        Color(0xFF1976D2),
        Color(0xFFFBC02D),
        Color(0xFF388E3C),
      ],
      primary: legoRed,
    );
  }

  static ThemeData _baseTheme({
    required List<Color> accentColors,
    required Color primary,
  }) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: _ink,
      secondary: accentColors.first,
      onSecondary: _ink,
      error: const Color(0xFFE57373),
      onError: _ink,
      background: _paperPrimary,
      onBackground: _ink,
      surface: _paperSecondary,
      onSurface: _ink,
    );

    return ThemeData(
      useMaterial3: false,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _paperPrimary,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 16,
          color: _ink,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _paperSecondary,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
