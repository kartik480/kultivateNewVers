import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App typography:
/// - [Geologica] (Google Fonts): calm sans for UI — regular/medium body, semibold+ for titles.
/// - Display phrases (Clicker Script) are set on specific widgets, not here.
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

    final geo = GoogleFonts.geologicaTextTheme(base.textTheme);

    TextStyle geoFrom(TextStyle? s, {FontWeight? weight}) => GoogleFonts.geologica(
          textStyle: s,
          fontWeight: weight,
          letterSpacing: -0.15,
        );

    return base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: GoogleFonts.geologica(color: Colors.white70, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.geologica(color: Colors.white38, fontWeight: FontWeight.w400),
        floatingLabelStyle:
            GoogleFonts.geologica(color: accentCyan.withValues(alpha: 0.95), fontWeight: FontWeight.w600),
      ),
      textTheme: geo.copyWith(
        displayLarge: geoFrom(geo.displayLarge, weight: FontWeight.w800),
        displayMedium: geoFrom(geo.displayMedium, weight: FontWeight.w800),
        displaySmall: geoFrom(geo.displaySmall, weight: FontWeight.w700),
        headlineLarge: geoFrom(geo.headlineLarge, weight: FontWeight.w700),
        headlineMedium: geoFrom(geo.headlineMedium, weight: FontWeight.w700),
        headlineSmall: geoFrom(geo.headlineSmall, weight: FontWeight.w700),
        titleLarge: geoFrom(geo.titleLarge, weight: FontWeight.w700),
        titleMedium: geoFrom(geo.titleMedium, weight: FontWeight.w600),
        titleSmall: geoFrom(geo.titleSmall, weight: FontWeight.w600),
        bodyLarge: GoogleFonts.geologica(textStyle: geo.bodyLarge, fontWeight: FontWeight.w400, height: 1.45),
        bodyMedium: GoogleFonts.geologica(textStyle: geo.bodyMedium, fontWeight: FontWeight.w400, height: 1.4),
        bodySmall: GoogleFonts.geologica(textStyle: geo.bodySmall, fontWeight: FontWeight.w400, height: 1.35),
        labelLarge: GoogleFonts.geologica(textStyle: geo.labelLarge, fontWeight: FontWeight.w600),
        labelMedium: GoogleFonts.geologica(textStyle: geo.labelMedium, fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.geologica(textStyle: geo.labelSmall, fontWeight: FontWeight.w500),
      ),
    );
  }
}
