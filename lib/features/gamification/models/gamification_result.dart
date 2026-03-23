import 'badge_definition.dart';
import 'challenge_definition.dart';
import 'gamification_tier.dart';
import 'level_system.dart';

/// Returned by GamificationService after processing a user action.
/// Drives the animation sequence: celebration → level-up overlay → badge toast.
class GamificationResult {
  const GamificationResult({
    required this.xpGained,
    required this.previousLevel,
    required this.newLevel,
    required this.previousTier,
    required this.newBadges,
    required this.completedChallenges,
  });

  final int xpGained;
  final int previousLevel;
  final int newLevel;
  final GamificationTier previousTier;
  final List<BadgeDefinition> newBadges;
  final List<ChallengeDefinition> completedChallenges;

  bool get leveledUp => newLevel > previousLevel;
  bool get tierChanged => newTier != previousTier;
  GamificationTier get newTier => LevelSystem.tierForLevel(newLevel);
  bool get hasBadges => newBadges.isNotEmpty;
  bool get hasAnyEvent => xpGained > 0 || hasBadges || completedChallenges.isNotEmpty;

  static const GamificationResult empty = GamificationResult(
    xpGained: 0,
    previousLevel: 1,
    newLevel: 1,
    previousTier: GamificationTier.bronze,
    newBadges: [],
    completedChallenges: [],
  );
}
