import 'package:flutter/material.dart';

enum GamificationTier { bronze, silver, gold, diamond }

extension GamificationTierX on GamificationTier {
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
        return const Color(0xFFFF9B3C); // vibrant copper-orange
      case GamificationTier.silver:
        return const Color(0xFFB8C8D8);
      case GamificationTier.gold:
        return const Color(0xFFFFD700);
      case GamificationTier.diamond:
        return const Color(0xFF00CFFF);
    }
  }

  List<Color> get gradient {
    switch (this) {
      case GamificationTier.bronze:
        // Warm copper tones — no dark brown
        return [const Color(0xFFFFB347), const Color(0xFFFF7C2A)];
      case GamificationTier.silver:
        return [const Color(0xFFE0E8F0), const Color(0xFF8A9AB0)];
      case GamificationTier.gold:
        return [const Color(0xFFFFE566), const Color(0xFFFFAA00)];
      case GamificationTier.diamond:
        return [const Color(0xFF00CFFF), const Color(0xFF7B2FBE), const Color(0xFFFF6EC7)];
    }
  }

  // Confetti colors: vivid mix so it never looks monochrome
  List<Color> get confettiColors {
    switch (this) {
      case GamificationTier.bronze:
        return [
          const Color(0xFFFFB347),
          const Color(0xFFFF7C2A),
          const Color(0xFFFFD700),
          Colors.white,
          const Color(0xFFFFE0A0),
        ];
      case GamificationTier.silver:
        return [
          const Color(0xFFE0E8F0),
          const Color(0xFF8A9AB0),
          Colors.white,
          const Color(0xFFB0C4DE),
          const Color(0xFF6EC6FF),
        ];
      case GamificationTier.gold:
        return [
          const Color(0xFFFFE566),
          const Color(0xFFFFAA00),
          Colors.white,
          const Color(0xFFFFD700),
          const Color(0xFFFFF0A0),
        ];
      case GamificationTier.diamond:
        return [
          const Color(0xFF00CFFF),
          const Color(0xFF7B2FBE),
          const Color(0xFFFF6EC7),
          Colors.white,
          const Color(0xFFA0FFEE),
        ];
    }
  }

  Color get backgroundColor {
    // All tiers use the same near-black so tier color pops, not blends in
    return const Color(0xFF080B12);
  }

  Color get glowColor {
    switch (this) {
      case GamificationTier.bronze:
        return const Color(0xFFFF9B3C);
      case GamificationTier.silver:
        return const Color(0xFFB8C8D8);
      case GamificationTier.gold:
        return const Color(0xFFFFD700);
      case GamificationTier.diamond:
        return const Color(0xFF00CFFF);
    }
  }
}
