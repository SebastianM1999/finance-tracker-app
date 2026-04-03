import '../models/gamification_models.dart';

/// Evaluates which badges should be unlocked given the current app state.
class BadgeService {
  const BadgeService();

  /// Returns all badges not yet unlocked that are now satisfied.
  List<BadgeDefinition> evaluate({
    required GamificationProfile profile,
    required BadgeContext ctx,
  }) {
    final unlocked = profile.unlockedBadgeIds.toSet();
    final newBadges = <BadgeDefinition>[];

    for (final badge in kAllBadges) {
      if (unlocked.contains(badge.id)) continue;
      if (_evaluate(badge.id, profile, ctx)) {
        newBadges.add(badge);
      }
    }

    return newBadges;
  }

  bool _evaluate(String id, GamificationProfile profile, BadgeContext ctx) {
    switch (id) {
      // ── Vermögen: w_net ──
      case 'w_net_bronze': return ctx.netWorth >= 1000;
      case 'w_net_silver': return ctx.netWorth >= 5000;
      case 'w_net_gold':   return ctx.netWorth >= 30000;
      case 'w_net_diamond': return ctx.netWorth >= 100000;

      // ── Vermögen: w_invest ──
      case 'w_invest_bronze': return ctx.investedTotal >= 500;
      case 'w_invest_silver': return ctx.investedTotal >= 3000;
      case 'w_invest_gold':   return ctx.investedTotal >= 15000;
      case 'w_invest_diamond': return ctx.investedTotal >= 50000;

      // ── Vermögen: w_pos ──
      case 'w_pos_bronze': return ctx.totalPositions >= 1;
      case 'w_pos_silver': return ctx.totalPositions >= 5;
      case 'w_pos_gold':   return ctx.totalPositions >= 15;
      case 'w_pos_diamond': return ctx.totalPositions >= 30;

      // ── Diversifikation: d_breadth ──
      case 'd_breadth_bronze': return ctx.activeCategories >= 2;
      case 'd_breadth_silver': return ctx.activeCategories >= 3;
      case 'd_breadth_gold':   return ctx.activeCategories >= 4;
      case 'd_breadth_diamond': return ctx.activeCategories >= 5;

      // ── Diversifikation: d_balance ──
      case 'd_balance_bronze': return _catsAbove(ctx.categoryValues, 500) >= 2;
      case 'd_balance_silver': return _catsAbove(ctx.categoryValues, 500) >= 3;
      case 'd_balance_gold':   return _catsAbove(ctx.categoryValues, 500) >= 4;
      case 'd_balance_diamond': return _catsAbove(ctx.categoryValues, 500) >= 5;

      // ── Diversifikation: d_spread ──
      case 'd_spread_bronze': return _largestCatPct(ctx) <= 0.80;
      case 'd_spread_silver': return _largestCatPct(ctx) <= 0.70;
      case 'd_spread_gold':   return _largestCatPct(ctx) <= 0.60;
      case 'd_spread_diamond': return _largestCatPct(ctx) <= 0.50;

      // ── Schuldenabbau: s_paid ──
      case 's_paid_bronze': return ctx.paidOffDebts >= 1;
      case 's_paid_silver': return ctx.paidOffDebts >= 2;
      case 's_paid_gold':   return ctx.paidOffDebts >= 4;
      case 's_paid_diamond': return ctx.paidOffDebts >= 7;

      // ── Schuldenabbau: s_free ──
      case 's_free_bronze': return ctx.paidOffDebts >= 1;
      case 's_free_silver': return ctx.activeDebts == 0 && ctx.totalDebtsEverAdded > 0;
      case 's_free_gold':   return ctx.activeDebts == 0 && ctx.paidOffDebts >= 3;
      case 's_free_diamond':
        final pathA = ctx.activeDebts == 0 && ctx.paidOffDebts >= 5;
        final age = DateTime.now().difference(profile.createdAt);
        final pathB = ctx.totalDebtsEverAdded == 0 && age.inDays >= 30;
        return pathA || pathB;

      // ── Dabei seit: t_age ──
      case 't_age_bronze': return DateTime.now().difference(profile.createdAt).inDays >= 2;
      case 't_age_silver': return DateTime.now().difference(profile.createdAt).inDays >= 30;
      case 't_age_gold':   return DateTime.now().difference(profile.createdAt).inDays >= 90;
      case 't_age_diamond': return DateTime.now().difference(profile.createdAt).inDays >= 365;

      // ── Festgeld: fg_count ──
      case 'fg_count_bronze': return ctx.festgeldCount >= 1;
      case 'fg_count_silver': return ctx.festgeldCount >= 2;
      case 'fg_count_gold':   return ctx.festgeldCount >= 3;
      case 'fg_count_diamond': return ctx.festgeldCount >= 5;

      // ── Festgeld: fg_vol ──
      case 'fg_vol_bronze': return ctx.festgeldTotal >= 500;
      case 'fg_vol_silver': return ctx.festgeldTotal >= 2000;
      case 'fg_vol_gold':   return ctx.festgeldTotal >= 10000;
      case 'fg_vol_diamond': return ctx.festgeldTotal >= 30000;

      // ── Festgeld: fg_mature ──
      case 'fg_mature_bronze': return ctx.matureCount >= 1;
      case 'fg_mature_silver': return ctx.matureCount >= 2;
      case 'fg_mature_gold':   return ctx.matureCount >= 4;
      case 'fg_mature_diamond': return ctx.matureCount >= 8;

      // ── Krypto: cr_count ──
      case 'cr_count_bronze': return ctx.cryptoPositions >= 1;
      case 'cr_count_silver': return ctx.cryptoPositions >= 2;
      case 'cr_count_gold':   return ctx.cryptoPositions >= 4;
      case 'cr_count_diamond': return ctx.cryptoPositions >= 8;

      // ── Krypto: cr_vol ──
      case 'cr_vol_bronze': return ctx.cryptoTotal >= 200;
      case 'cr_vol_silver': return ctx.cryptoTotal >= 1000;
      case 'cr_vol_gold':   return ctx.cryptoTotal >= 8000;
      case 'cr_vol_diamond': return ctx.cryptoTotal >= 25000;

      // ── Krypto: cr_ratio ──
      case 'cr_ratio_bronze': return _ratio(ctx.cryptoTotal, ctx.netWorth) >= 0.01;
      case 'cr_ratio_silver': return _ratio(ctx.cryptoTotal, ctx.netWorth) >= 0.05;
      case 'cr_ratio_gold':   return _ratio(ctx.cryptoTotal, ctx.netWorth) >= 0.15;
      case 'cr_ratio_diamond': return _ratio(ctx.cryptoTotal, ctx.netWorth) >= 0.30;

      // ── ETF: etf_count ──
      case 'etf_count_bronze': return ctx.etfPositions >= 1;
      case 'etf_count_silver': return ctx.etfPositions >= 2;
      case 'etf_count_gold':   return ctx.etfPositions >= 4;
      case 'etf_count_diamond': return ctx.etfPositions >= 8;

      // ── ETF: etf_vol ──
      case 'etf_vol_bronze': return ctx.etfTotal >= 500;
      case 'etf_vol_silver': return ctx.etfTotal >= 3000;
      case 'etf_vol_gold':   return ctx.etfTotal >= 15000;
      case 'etf_vol_diamond': return ctx.etfTotal >= 50000;

      // ── ETF: etf_ratio ──
      case 'etf_ratio_bronze': return _ratio(ctx.etfTotal, ctx.netWorth) >= 0.05;
      case 'etf_ratio_silver': return _ratio(ctx.etfTotal, ctx.netWorth) >= 0.15;
      case 'etf_ratio_gold':   return _ratio(ctx.etfTotal, ctx.netWorth) >= 0.30;
      case 'etf_ratio_diamond': return _ratio(ctx.etfTotal, ctx.netWorth) >= 0.50;

      // ── Konsequenz: k_updates ──
      case 'k_updates_bronze': return profile.updateCount >= 5;
      case 'k_updates_silver': return profile.updateCount >= 15;
      case 'k_updates_gold':   return profile.updateCount >= 40;
      case 'k_updates_diamond': return profile.updateCount >= 80;

      // ── Konsequenz: k_rich ──
      case 'k_rich_bronze': return ctx.posAbove1k >= 1;
      case 'k_rich_silver': return ctx.posAbove1k >= 3;
      case 'k_rich_gold':   return ctx.posAbove1k >= 6;
      case 'k_rich_diamond': return ctx.posAbove1k >= 12;

      // ── Konsequenz: k_wealth ──
      case 'k_wealth_bronze': return ctx.posAbove5k >= 1;
      case 'k_wealth_silver': return ctx.posAbove5k >= 2;
      case 'k_wealth_gold':   return ctx.posAbove5k >= 4;
      case 'k_wealth_diamond': return ctx.posAbove5k >= 8;

      // ── Sachwerte: phys_count ──
      case 'phys_count_bronze': return ctx.physicalCount >= 1;
      case 'phys_count_silver': return ctx.physicalCount >= 2;
      case 'phys_count_gold':   return ctx.physicalCount >= 4;
      case 'phys_count_diamond': return ctx.physicalCount >= 8;

      // ── Sachwerte: phys_vol ──
      case 'phys_vol_bronze': return ctx.physicalTotal >= 200;
      case 'phys_vol_silver': return ctx.physicalTotal >= 1000;
      case 'phys_vol_gold':   return ctx.physicalTotal >= 5000;
      case 'phys_vol_diamond': return ctx.physicalTotal >= 20000;

      // ── Sachwerte: phys_metals ──
      case 'phys_metals_bronze': return ctx.physicalGoldCount >= 1 || ctx.physicalSilverCount >= 1;
      case 'phys_metals_silver': return ctx.physicalGoldCount >= 1 && ctx.physicalSilverCount >= 1;
      case 'phys_metals_gold':   return ctx.physicalMetalsTotal >= 2000;
      case 'phys_metals_diamond': return ctx.physicalMetalsTotal >= 10000;

      default: return false;
    }
  }

  static int _catsAbove(Map<String, double> values, double threshold) =>
      values.values.where((v) => v >= threshold).length;

  static double _largestCatPct(BadgeContext ctx) {
    if (ctx.netWorth <= 0 || ctx.categoryValues.isEmpty) return 1.0;
    final positiveValues = ctx.categoryValues.values.where((v) => v > 0);
    if (positiveValues.isEmpty) return 1.0;
    final largest = positiveValues.reduce((a, b) => a > b ? a : b);
    final total = positiveValues.reduce((a, b) => a + b);
    return total > 0 ? largest / total : 1.0;
  }

  static double _ratio(double part, double total) {
    if (total <= 0) return 0.0;
    return part / total;
  }
}

/// Snapshot of the current app state needed for badge evaluation.
/// Assembled once per GamificationService call.
class BadgeContext {
  const BadgeContext({
    required this.netWorth,
    required this.activeCategories,
    required this.categoryValues,
    required this.totalDebtsEverAdded,
    required this.activeDebts,
    required this.paidOffDebts,
    required this.daysSinceLastDebtAdded,
    required this.festgeldCount,
    required this.festgeldTotal,
    required this.cryptoPositions,
    required this.cryptoTotal,
    required this.etfPositions,
    required this.etfTotal,
    required this.investedTotal,
    required this.totalPositions,
    required this.matureCount,
    required this.posAbove1k,
    required this.posAbove5k,
    required this.physicalCount,
    required this.physicalTotal,
    required this.physicalGoldCount,
    required this.physicalSilverCount,
    required this.physicalMetalsTotal,
  });

  final double netWorth;
  final int activeCategories;

  /// Map of category key → total value (asset categories only, not Schulden).
  final Map<String, double> categoryValues;

  final int totalDebtsEverAdded;
  final int activeDebts;
  final int paidOffDebts;
  final int daysSinceLastDebtAdded;

  final int festgeldCount;
  final double festgeldTotal;

  final int cryptoPositions;
  final double cryptoTotal;

  final int etfPositions;
  final double etfTotal;

  /// ETF + crypto + festgeld + physical assets (excludes giro).
  final double investedTotal;

  /// Total positions across all categories.
  final int totalPositions;

  /// Number of matured Festgelder (persisted in profile).
  final int matureCount;

  /// Positions with value >= €1.000.
  final int posAbove1k;

  /// Positions with value >= €5.000.
  final int posAbove5k;

  /// Total number of physical asset positions.
  final int physicalCount;

  /// Total current value of all physical assets.
  final double physicalTotal;

  /// Number of gold positions.
  final int physicalGoldCount;

  /// Number of silver positions.
  final int physicalSilverCount;

  /// Total current value of gold + silver positions.
  final double physicalMetalsTotal;

  /// Number of categories where value >= [minValue].
  int categoriesWithMinValue(double minValue) =>
      categoryValues.values.where((v) => v >= minValue).length;
}
