import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {

  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.darkSurface,
    ),
    cardColor: AppColors.darkCard,
  );

  static final light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      surface: AppColors.lightSurface,
    ),
    cardColor: AppColors.lightCard,
  );
}
