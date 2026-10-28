import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Migrant Hub palette: #A7EBF2 #54ACBF #26658C #023859 #011C40 on a white, softly glassy canvas.
class AppColors {
  static const sky = Color(0xFFA7EBF2);
  static const teal = Color(0xFF54ACBF);
  static const primary = Color(0xFF26658C);
  static const navy = Color(0xFF023859);
  static const ink = Color(0xFF011C40);
  static const canvas = Color(0xFFF5F8FA);
  static const muted = Color(0xFF6B7A89);
  static const line = Color(0x14011C40);
  static const danger = Color(0xFFD64545);
  static const success = Color(0xFF2E9E6A);

  // chat
  static const chatBg = Color(0xFFE3EEF2);
  static const bubbleMine = Color(0xFFD8F1F5);
  static const bubbleOther = Colors.white;
  static const tickSeen = Color(0xFF2A9BD1);

  static const nameColors = [
    Color(0xFF26658C), Color(0xFFA0522D), Color(0xFF2E7D6B), Color(0xFF7B4FA0),
    Color(0xFFB5651D), Color(0xFF1F6FA8), Color(0xFFA8325E),
  ];
  static Color nameColor(String id) => nameColors[id.hashCode.abs() % nameColors.length];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, secondary: AppColors.teal, surface: Colors.white),
    scaffoldBackgroundColor: AppColors.canvas,
  );
  final text = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink),
      titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
      titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.ink,
      titleTextStyle: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.sky.withValues(alpha: .55),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerColor: AppColors.line,
  );
}
