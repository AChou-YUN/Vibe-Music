import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A1A);
  static const surfaceLight = Color(0xFF2A2A2A);
  static const accent = Color(0xFFFF6B35);
  static const accentPurple = Color(0xFF7C4DFF);
  static const textPrimary = Color(0xDEFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const textDisabled = Color(0x61FFFFFF);
  static const divider = Color(0x1AFFFFFF);
  static const error = Color(0xFFCF6679);
}

class AppTheme {
  static ThemeData dark({Color accentColor = AppColors.accent}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        surface: AppColors.surface,
        primary: accentColor,
        secondary: AppColors.accentPurple,
        onSurface: AppColors.textPrimary,
      ),
      dividerColor: AppColors.divider,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: AppColors.surfaceLight,
        thumbColor: accentColor,
        overlayColor: accentColor.withValues(alpha: 0.16),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
    );
  }
}
