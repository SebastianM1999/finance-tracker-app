import 'badge_definition.dart';

/// Returned by GamificationService after processing a user action.
/// Drives the badge toast animation sequence.
class GamificationResult {
  const GamificationResult({
    required this.newBadges,
  });

  final List<BadgeDefinition> newBadges;

  bool get hasBadges => newBadges.isNotEmpty;
  bool get hasAnyEvent => hasBadges;

  static const GamificationResult empty = GamificationResult(
    newBadges: [],
  );
}
