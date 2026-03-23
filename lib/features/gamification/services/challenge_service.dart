import '../models/gamification_models.dart';
import '../services/badge_service.dart';

/// Evaluates which challenges are now completed.
class ChallengeService {
  const ChallengeService();

  /// Returns permanent challenges that just became complete.
  List<ChallengeDefinition> evaluatePermanent({
    required GamificationProfile profile,
    required BadgeContext ctx,
  }) {
    final done = profile.completedChallengeIds.toSet();
    final completed = <ChallengeDefinition>[];

    for (final c in kPermanentChallenges) {
      if (done.contains(c.id)) continue;
      if (_isPermanentSatisfied(c.id, ctx)) {
        completed.add(c);
      }
    }

    return completed;
  }

  bool _isPermanentSatisfied(String id, BadgeContext ctx) {
    switch (id) {
      case 'first_position':
        return ctx.activeCategories >= 1;
      case 'three_categories':
        return ctx.activeCategories >= 3;
      case 'all_categories':
        return ctx.activeCategories >= 6;
      case 'debt_free':
        return ctx.activeDebts == 0 && ctx.totalDebtsEverAdded > 0;
      case 'five_figures':
        return ctx.netWorth >= 10000;
      case 'six_figures':
        return ctx.netWorth >= 100000;
      case 'millionaire':
        return ctx.netWorth >= 1000000;
      case 'festgeld_matured':
        // Signaled externally when a Festgeld matures.
        return false;
      case 'three_month_growth':
        // Signaled externally after 3 consecutive positive months.
        return false;
      default:
        return false;
    }
  }
}
