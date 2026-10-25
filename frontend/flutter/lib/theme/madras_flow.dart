import 'package:flutter/material.dart';

/// Madras Flow — warm, rider-friendly design language.
/// Spec: docs/DESIGN.md
class Mf {
  static const _displayFamily = 'BricolageGrotesque';
  static const _bodyFamily = 'PublicSans';

  // Palette
  static const paper = Color(0xFFFAF6EF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2EAE0);
  static const ink = Color(0xFF1E2A32);
  static const inkMuted = Color(0xFF5B6B76);
  static const inkFaint = Color(0xFF93A1AC);
  static const amber = Color(0xFFF2A93B);
  static const amberPress = Color(0xFFD98E1F);
  static const teal = Color(0xFF12737E);
  static const tealSoft = Color(0xFFE0F2F4);
  static const green = Color(0xFF2E9E5B);
  static const greenSoft = Color(0xFFE3F5E9);
  static const coral = Color(0xFFD95D39);
  static const coralSoft = Color(0xFFFBEAE4);
  static const hairline = Color(0xFFEADFD0);
  static const white = Color(0xFFFFFFFF);

  // Type
  static TextStyle display(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w700,
  }) => TextStyle(
    fontFamily: _displayFamily,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.15,
  );

  static TextStyle body(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: _bodyFamily,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.35,
  );

  static TextStyle overline({Color color = teal}) => TextStyle(
    fontFamily: _bodyFamily,
    fontSize: 11,
    color: color,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
  );

  static TextStyle price(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w700,
  }) => TextStyle(
    fontFamily: _bodyFamily,
    fontSize: size,
    color: color,
    fontWeight: weight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static ThemeData theme() {
    final base = ThemeData(useMaterial3: true, fontFamily: _bodyFamily);
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: amber,
        brightness: Brightness.light,
        surface: surface,
        primary: amber,
        secondary: teal,
        error: coral,
        onSurface: ink,
      ),
      textTheme: TextTheme(
        displayLarge: display(40),
        displayMedium: display(32),
        headlineMedium: display(28),
        titleLarge: display(22),
        titleMedium: display(18),
        bodyLarge: body(16),
        bodyMedium: body(14, color: inkMuted),
        labelLarge: body(15, weight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: hairline,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
      ),
    );
  }
}
