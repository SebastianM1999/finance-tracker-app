import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Dark Mode ---
  static const darkBackground = Color(0xFF0D0F14);
  static const darkSurface = Color(0xFF161B22);
  static const darkSurfaceVariant = Color(0xFF1E2530);
  static const darkPrimary = Color(0xFF6C63FF);
  static const darkSecondary = Color(0xFFFF6B6B);
  static const darkPositive = Color(0xFF4CAF82);
  static const darkWarning = Color(0xFFFFB347);
  static const darkText = Color(0xFFF0F0F0);
  static const darkTextSecondary = Color(0xFF8B8FA8);
  static const darkBorder = Color(0xFF2A3142);

  // --- Light Mode ---
  static const lightBackground = Color(0xFFF0F4FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFE8EEFF);
  static const lightPrimary = Color(0xFF5B52E8);
  static const lightSecondary = Color(0xFFE5534B);
  static const lightPositive = Color(0xFF2E8B57);
  static const lightWarning = Color(0xFFD4790A);
  static const lightText = Color(0xFF0D0F14);
  static const lightTextSecondary = Color(0xFF5A6070);
  static const lightBorder = Color(0xFFD0D5E8);

  // --- Chart Colors (brighter than gradient starts for chart visibility) ---
  static const chartGiro     = Color(0xFF7B8FFF);
  static const chartFestgeld = Color(0xFFE090E0);
  static const chartEtf      = Color(0xFF4DB8F5);
  static const chartCrypto   = Color(0xFFEE7AA0);
  static const chartPhysical = Color(0xFF4DD87C);

  // --- Category Gradients ---
  static const gradientGiro = [Color(0xFF5265BB), Color(0xFF5E3C82)];
  static const gradientFestgeld = [Color(0xFFC076C9), Color(0xFFC44656)];
  static const gradientEtf = [Color(0xFF3F8ACB), Color(0xFF00C2CB)];
  static const gradientCrypto = [Color(0xFFC85A7B), Color(0xFFCBB433)];
  static const gradientPhysical = [Color(0xFF36BA62), Color(0xFF2DC7AC)];
  static const gradientSchulden = [Color(0xFFCC5656), Color(0xFFBE0761)];

  // --- Theme-aware helpers ---
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color positive(BuildContext context) =>
      _isDark(context) ? darkPositive : lightPositive;

  static Color warning(BuildContext context) =>
      _isDark(context) ? darkWarning : lightWarning;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color surface(BuildContext context) =>
      _isDark(context) ? darkSurface : lightSurface;

  static Color surfaceVariant(BuildContext context) =>
      _isDark(context) ? darkSurfaceVariant : lightSurfaceVariant;

  static Color border(BuildContext context) =>
      _isDark(context) ? darkBorder : lightBorder;

  static Color primary(BuildContext context) =>
      _isDark(context) ? darkPrimary : lightPrimary;

  static Color secondary(BuildContext context) =>
      _isDark(context) ? darkSecondary : lightSecondary;
}
