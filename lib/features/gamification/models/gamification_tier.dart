import 'package:flutter/material.dart';

/// Badge rarity tier — also used for visual styling of badge cards, toasts, and the avatar ring.
enum GamificationTier {
  bronze,
  silver,
  gold,
  diamond;

  String get label {
    switch (this) {
      case GamificationTier.bronze:
        return 'Bronze';
      case GamificationTier.silver:
        return 'Silber';
      case GamificationTier.gold:
        return 'Gold';
      case GamificationTier.diamond:
        return 'Diamant';
    }
  }

  Color get primaryColor {
    switch (this) {
      case GamificationTier.bronze:
        return const Color(0xFFCD7F32);
      case GamificationTier.silver:
        return const Color(0xFFB8C8D8);
      case GamificationTier.gold:
        return const Color(0xFFD4A017);
      case GamificationTier.diamond:
        return const Color(0xFF00CFFF);
    }
  }

  List<Color> get gradient {
    switch (this) {
      case GamificationTier.bronze:
        return const [Color(0xFF5C2700), Color(0xFFCD7F32), Color(0xFFFF9B3C), Color(0xFFFFD090), Color(0xFFFF9B3C), Color(0xFFCD7F32), Color(0xFF5C2700)];
      case GamificationTier.silver:
        return const [Color(0xFF4A5A6A), Color(0xFF9AAABB), Color(0xFFD8E8F0), Color(0xFFFFFFFF), Color(0xFFD8E8F0), Color(0xFF9AAABB), Color(0xFF4A5A6A)];
      case GamificationTier.gold:
        return const [Color(0xFF4A2800), Color(0xFFB8860B), Color(0xFFD4A017), Color(0xFFFFF0A0), Color(0xFFD4A017), Color(0xFFB8860B), Color(0xFF4A2800)];
      case GamificationTier.diamond:
        return const [Color(0xFF001A3A), Color(0xFF0077BB), Color(0xFF00CFFF), Color(0xFFAAEEFF), Color(0xFF00CFFF), Color(0xFF0077BB), Color(0xFF001A3A)];
    }
  }
}
