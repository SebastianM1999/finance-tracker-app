import 'gamification_tier.dart';

/// Flat level curve: 200 XP per level, 100 levels total (20,000 XP max).
/// Tier thresholds: Bronze L1-5, Silver L6-14, Gold L15-39, Diamond L40-100.
class LevelSystem {
  const LevelSystem._();

  static const int xpPerLevel = 200;
  static const int maxLevel = 100;

  static const int silverThreshold = 6;
  static const int goldThreshold = 15;
  static const int diamondThreshold = 40;

  /// Level from total accumulated XP. Clamped to [1, maxLevel].
  static int levelFromXP(int totalXP) {
    if (totalXP <= 0) return 1;
    return ((totalXP ~/ xpPerLevel) + 1).clamp(1, maxLevel);
  }

  /// XP needed to reach a given level (total from zero).
  static int totalXPForLevel(int level) => (level - 1) * xpPerLevel;

  /// XP accumulated inside the current level (0..xpPerLevel-1).
  static int xpIntoCurrentLevel(int totalXP) {
    if (totalXP <= 0) return 0;
    final level = levelFromXP(totalXP);
    if (level >= maxLevel) return xpPerLevel; // full bar at max
    return totalXP - totalXPForLevel(level);
  }

  /// XP remaining until next level.
  static int xpToNextLevel(int totalXP) {
    final level = levelFromXP(totalXP);
    if (level >= maxLevel) return 0;
    return xpPerLevel - xpIntoCurrentLevel(totalXP);
  }

  /// Progress fraction 0.0..1.0 within the current level.
  static double levelProgress(int totalXP) {
    if (totalXP <= 0) return 0.0;
    final level = levelFromXP(totalXP);
    if (level >= maxLevel) return 1.0;
    return xpIntoCurrentLevel(totalXP) / xpPerLevel;
  }

  /// Tier for a given level.
  static GamificationTier tierForLevel(int level) {
    if (level >= diamondThreshold) return GamificationTier.diamond;
    if (level >= goldThreshold) return GamificationTier.gold;
    if (level >= silverThreshold) return GamificationTier.silver;
    return GamificationTier.bronze;
  }

  /// Tier derived directly from total XP.
  static GamificationTier tierFromXP(int totalXP) =>
      tierForLevel(levelFromXP(totalXP));
}
