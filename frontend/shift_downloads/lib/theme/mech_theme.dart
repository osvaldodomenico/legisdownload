import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechColors {
  static const background = Color(0xFF050810);
  static const surface = Color(0xFF0A1220);
  static const surfaceAlt = Color(0xFF080C14);
  static const border = Color(0xFF1A3A5C);
  static const borderAlt = Color(0xFF1E3A5F);
  static const accentYellow = Color(0xFFF5A623);
  static const accentYellowDim = Color(0x44F5A623);
  static const accentCyan = Color(0xFF00D4FF);
  static const accentCyanDim = Color(0x4400D4FF);
  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF3A6080);
  static const textMuted = Color(0xFF2A4A6A);
  static const error = Color(0xFFFF4444);
}

class MechTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MechColors.background,
        colorScheme: const ColorScheme.dark(
          primary: MechColors.accentYellow,
          secondary: MechColors.accentCyan,
          surface: MechColors.surface,
          error: MechColors.error,
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          const TextTheme(
            headlineSmall: TextStyle(
              color: MechColors.accentYellow,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
            bodyMedium: TextStyle(color: MechColors.textPrimary),
            bodySmall: TextStyle(color: MechColors.textSecondary, letterSpacing: 1.0),
            labelSmall: TextStyle(color: MechColors.textMuted, letterSpacing: 1.5),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: MechColors.accentCyan,
          unselectedLabelColor: MechColors.textMuted,
          indicator: BoxDecoration(
            border: Border(bottom: BorderSide(color: MechColors.accentCyan, width: 2)),
          ),
        ),
        dividerColor: MechColors.border,
      );
}
