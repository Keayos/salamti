import 'package:flutter/material.dart';

class AppColors {
  static const Color bg = Color(0xFF0B1120);
  static const Color card = Color(0xFF131F30);
  static const Color card2 = Color(0xFF1A2840);
  static const Color border = Color(0xFF1E3050);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueLight = Color(0xFF3B82F6);
  static const Color blueDim = Color(0xFF1D4ED8);
  static const Color red = Color(0xFFEF4444);
  static const Color green = Color(0xFF22C55E);
  static const Color yellow = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF7A9AB5);
  static const Color textMuted = Color(0xFF3D5A75);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.blue,
      surface: AppColors.card,
    ),
    fontFamily: 'Outfit',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Outfit',
      ),
      iconTheme: IconThemeData(color: AppColors.blueLight),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Outfit',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Outfit'),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Outfit'),
    ),
  );
}
