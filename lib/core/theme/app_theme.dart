import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.darkSurface,
          surfaceContainerHighest: AppColors.darkSurfaceVariant,
          primary: AppColors.darkPrimary,
          secondary: AppColors.darkSecondary,
          error: AppColors.darkSecondary,
          onSurface: AppColors.darkText,
          onPrimary: Colors.white,
          outline: AppColors.darkBorder,
        ),
        textTheme: _textTheme(AppColors.darkText, AppColors.darkTextSecondary),
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: _inputTheme(
          AppColors.darkSurface,
          AppColors.darkBorder,
          AppColors.darkTextSecondary,
          AppColors.darkPrimary,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.darkPrimary,
          unselectedItemColor: AppColors.darkTextSecondary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          centerTitle: false,
        ),
        tabBarTheme: const TabBarThemeData(
          dividerColor: AppColors.darkBorder,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.darkSurfaceVariant,
          contentTextStyle: TextStyle(color: AppColors.darkText),
          behavior: SnackBarBehavior.floating,
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.darkPrimary,
            selectedForegroundColor: Colors.white,
          ),
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        colorScheme: const ColorScheme.light(
          surface: AppColors.lightSurface,
          surfaceContainerHighest: AppColors.lightSurfaceVariant,
          primary: AppColors.lightPrimary,
          secondary: AppColors.lightSecondary,
          error: AppColors.lightSecondary,
          onSurface: AppColors.lightText,
          onPrimary: Colors.white,
          outline: AppColors.lightBorder,
        ),
        textTheme: _textTheme(AppColors.lightText, AppColors.lightTextSecondary),
        cardTheme: CardThemeData(
          color: AppColors.lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.lightBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: _inputTheme(
          AppColors.lightSurface,
          AppColors.lightBorder,
          AppColors.lightTextSecondary,
          AppColors.lightPrimary,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.lightSurface,
          selectedItemColor: AppColors.lightPrimary,
          unselectedItemColor: AppColors.lightTextSecondary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightBorder,
          thickness: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightBackground,
          foregroundColor: AppColors.lightText,
          elevation: 0,
          centerTitle: false,
        ),
        tabBarTheme: const TabBarThemeData(
          dividerColor: AppColors.lightBorder,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          contentTextStyle: TextStyle(color: AppColors.lightText),
          behavior: SnackBarBehavior.floating,
        ),
      );

  static TextTheme _textTheme(Color text, Color secondary) => TextTheme(
        headlineLarge: AppTextStyles.headlineLarge.copyWith(color: text),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(color: text),
        titleLarge: AppTextStyles.titleLarge.copyWith(color: text),
        titleMedium: AppTextStyles.titleMedium.copyWith(color: text),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: text),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: secondary),
        labelSmall: AppTextStyles.labelSmall.copyWith(color: secondary),
      );

  static InputDecorationTheme _inputTheme(
    Color fill,
    Color border,
    Color hint,
    Color focus,
  ) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: TextStyle(color: hint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkSecondary),
        ),
      );
}
