import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color black = Color(0xFF000000);
  static const Color card = Color(0xFF110B1C);
  static const Color border = Color(0xFF2A1F3F);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFB794F6);
  static const Color text = Color(0xFFEDE9F5);
  static const Color muted = Color(0xFF9A90B0);
  static const Color amber = Color(0xFFF5B942);
  static const Color green = Color(0xFF4ADE80);
  static const Color blue = Color(0xFF60A5FA);
  static const Color red = Color(0xFFFF6B81);
  static const Color grey = Color(0xFF7C7590);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.purple,
      onPrimary: Colors.white,
      secondary: AppColors.purpleLight,
      surface: AppColors.black,
      onSurface: AppColors.text,
      error: AppColors.red,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.black,
      canvasColor: AppColors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B0714),
        indicatorColor: const Color(0xFF3B2A63),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, color: AppColors.text),
        ),
      ),
      dividerColor: AppColors.border,
    );
  }
}
