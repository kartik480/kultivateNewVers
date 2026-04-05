import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Habit / wellness typography:
/// - [Fraunces]: soft variable serif for titles — journal, growth, “ritual” energy.
/// - [Nunito]: rounded, friendly sans for body — approachable daily tracking.
class KultivateTheme {
  KultivateTheme._();

  static const Color accentCyan = Color(0xFF00D9FF);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentCyan,
        brightness: Brightness.dark,
        surface: const Color(0xFF0F1023),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F1023),
    );

    final nunito = GoogleFonts.nunitoTextTheme(base.textTheme);

    TextStyle frauncesFrom(TextStyle? s, {FontWeight? weight}) => GoogleFonts.fraunces(
          textStyle: s,
          fontWeight: weight,
          letterSpacing: -0.35,
        );

    return base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: GoogleFonts.nunito(color: Colors.white70, fontWeight: FontWeight.w600),
        hintStyle: GoogleFonts.nunito(color: Colors.white38),
        floatingLabelStyle: GoogleFonts.nunito(color: accentCyan.withValues(alpha: 0.95), fontWeight: FontWeight.w700),
      ),
      textTheme: nunito.copyWith(
        displayLarge: frauncesFrom(nunito.displayLarge, weight: FontWeight.w800),
        displayMedium: frauncesFrom(nunito.displayMedium, weight: FontWeight.w800),
        displaySmall: frauncesFrom(nunito.displaySmall, weight: FontWeight.w700),
        headlineLarge: frauncesFrom(nunito.headlineLarge, weight: FontWeight.w700),
        headlineMedium: frauncesFrom(nunito.headlineMedium, weight: FontWeight.w700),
        headlineSmall: frauncesFrom(nunito.headlineSmall, weight: FontWeight.w700),
        titleLarge: frauncesFrom(nunito.titleLarge, weight: FontWeight.w700),
        titleMedium: frauncesFrom(nunito.titleMedium, weight: FontWeight.w600),
        titleSmall: frauncesFrom(nunito.titleSmall, weight: FontWeight.w600),
        bodyLarge: GoogleFonts.nunito(textStyle: nunito.bodyLarge, fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.nunito(textStyle: nunito.bodyMedium, fontWeight: FontWeight.w500),
        bodySmall: GoogleFonts.nunito(textStyle: nunito.bodySmall, fontWeight: FontWeight.w500),
        labelLarge: GoogleFonts.nunito(textStyle: nunito.labelLarge, fontWeight: FontWeight.w700),
        labelMedium: GoogleFonts.nunito(textStyle: nunito.labelMedium, fontWeight: FontWeight.w600),
        labelSmall: GoogleFonts.nunito(textStyle: nunito.labelSmall, fontWeight: FontWeight.w600),
      ),
    );
  }
}
