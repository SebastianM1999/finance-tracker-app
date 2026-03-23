import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../home/providers/home_providers.dart';
import '../data/gamification_repository.dart';
import '../models/gamification_models.dart';
import '../services/badge_service.dart';
import '../services/challenge_service.dart';
import '../services/gamification_service.dart';
import '../services/xp_service.dart';

// ── Unseen badge counters (ephemeral, session-only) ───────────────────────────

// Shown on the Home tab bottom nav icon — clears when Home tab is tapped.
final homeTabBadgeCountProvider = StateNotifierProvider<_NewBadgeNotifier, int>(
  (_) => _NewBadgeNotifier(),
);

// Shown on the avatar and in the sidebar — clears when the sidebar is opened
// or "Meine Badges" is tapped. Independent from the Home tab badge.
final newBadgeCountProvider = StateNotifierProvider<_NewBadgeNotifier, int>(
  (_) => _NewBadgeNotifier(),
);

class _NewBadgeNotifier extends StateNotifier<int> {
  _NewBadgeNotifier() : super(0);
  void add(int count) => state = state + count;
  void clear() => state = 0;
}

// ── Level-up pulse signal (ephemeral, session-only) ──────────────────────────

// Set to the new tier when a level-up occurs; avatar widgets watch this and
// play a pulse animation, then clear it back to null.
final levelUpTierProvider = StateProvider<GamificationTier?>((ref) => null);

// ── Repository ────────────────────────────────────────────────────────────────

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return GamificationRepository(uid);
});

// ── Services ──────────────────────────────────────────────────────────────────

final xpServiceProvider = Provider<XPService>((ref) => const XPService());

final badgeServiceProvider = Provider<BadgeService>((ref) => const BadgeService());

final challengeServiceProvider =
    Provider<ChallengeService>((ref) => const ChallengeService());

final gamificationServiceProvider = Provider<GamificationService>((ref) {
  return GamificationService(
    repository: ref.watch(gamificationRepositoryProvider),
    xpService: ref.watch(xpServiceProvider),
    badgeService: ref.watch(badgeServiceProvider),
    challengeService: ref.watch(challengeServiceProvider),
  );
});

// ── Profile stream ─────────────────────────────────────────────────────────────

final gamificationProfileProvider =
    StreamProvider<GamificationProfile?>((ref) {
  return ref.watch(gamificationRepositoryProvider).watchProfile();
});

// ── BadgeContext derived from existing streams ─────────────────────────────────

/// Assembles the current BadgeContext from all live data streams + gamification profile.
/// Recomputes whenever any stream emits new data.
final badgeContextProvider = Provider<BadgeContext?>((ref) {
  final giro = ref.watch(giroStreamProvider).valueOrNull;
  final festgeldList = ref.watch(festgeldStreamProvider).valueOrNull;
  final etfList = ref.watch(etfStreamProvider).valueOrNull;
  final cryptoList = ref.watch(cryptoStreamProvider).valueOrNull;
  final assetsList = ref.watch(assetsStreamProvider).valueOrNull;
  final schuldenList = ref.watch(schuldenStreamProvider).valueOrNull;
  final profile = ref.watch(gamificationProfileProvider).valueOrNull;

  // Wait until all streams are loaded
  if (giro == null ||
      festgeldList == null ||
      etfList == null ||
      cryptoList == null ||
      assetsList == null ||
      schuldenList == null) {
    return null;
  }

  final giroTotal = giro.fold(0.0, (s, a) => s + a.balance);
  final festgeldTotal = festgeldList.fold(0.0, (s, f) => s + f.amount);
  final etfTotal = etfList.fold(0.0, (s, e) => s + e.currentValue);
  final cryptoTotal = cryptoList.fold(0.0, (s, c) => s + c.currentValue);
  final assetsTotal = assetsList.fold(0.0, (s, a) => s + a.currentValue);
  final schuldenTotal = schuldenList.fold(
      0.0, (s, d) => s + (d.iOwe ? -d.amount : d.amount));

  final netWorth =
      giroTotal + festgeldTotal + etfTotal + cryptoTotal + assetsTotal + schuldenTotal;

  // Active asset categories (categories with at least 1 position)
  final categoryValues = <String, double>{};
  if (giro.isNotEmpty) categoryValues['giro'] = giroTotal;
  if (festgeldList.isNotEmpty) categoryValues['festgeld'] = festgeldTotal;
  if (etfList.isNotEmpty) categoryValues['etf'] = etfTotal;
  if (cryptoList.isNotEmpty) categoryValues['crypto'] = cryptoTotal;
  if (assetsList.isNotEmpty) categoryValues['physical'] = assetsTotal;

  // Schulden counts as a category for diversification if user has any debts
  final activeDebts = schuldenList.where((d) => d.iOwe).length;
  if (schuldenList.isNotEmpty) categoryValues['schulden'] = 0; // presence only

  final activeCategories = categoryValues.length;

  // daysSinceLastDebtAdded — from latest createdAt in schulden stream
  final sortedDebtDates = schuldenList.map((d) => d.createdAt).toList()
    ..sort((a, b) => b.compareTo(a));
  // When list is empty the user just cleared debts now — use 0, not 9999,
  // so the diamond badge isn't awarded instantly on deletion.
  final daysSinceLast = sortedDebtDates.isEmpty
      ? 0
      : DateTime.now().difference(sortedDebtDates.first).inDays;

  // paidOffDebts tracked in profile to persist across deletions
  final paidOffDebts = profile?.paidOffDebts ?? 0;

  // Physical asset breakdowns
  final physicalGoldCount = assetsList.where((a) => a.assetType == 'Gold').length;
  final physicalSilverCount = assetsList.where((a) => a.assetType == 'Silver').length;
  final physicalMetalsTotal = assetsList
      .where((a) => a.assetType == 'Gold' || a.assetType == 'Silver')
      .fold(0.0, (s, a) => s + a.currentValue);

  // New context fields
  final investedTotal = festgeldTotal + etfTotal + cryptoTotal + assetsTotal;

  final totalPositions = (giro.length) +
      festgeldList.length +
      etfList.length +
      cryptoList.length +
      assetsList.length +
      schuldenList.length;

  final allPositionValues = [
    ...giro.map((a) => a.balance),
    ...festgeldList.map((f) => f.amount),
    ...etfList.map((e) => e.currentValue),
    ...cryptoList.map((c) => c.currentValue),
    ...assetsList.map((a) => a.currentValue),
  ];
  final posAbove1k = allPositionValues.where((v) => v >= 1000).length;
  final posAbove5k = allPositionValues.where((v) => v >= 5000).length;
  final matureCount = profile?.matureCount ?? 0;

  return BadgeContext(
    netWorth: netWorth,
    activeCategories: activeCategories,
    categoryValues: categoryValues,
    totalDebtsEverAdded: schuldenList.length + paidOffDebts,
    activeDebts: activeDebts,
    paidOffDebts: paidOffDebts,
    daysSinceLastDebtAdded: daysSinceLast,
    festgeldCount: festgeldList.length,
    festgeldTotal: festgeldTotal,
    cryptoPositions: cryptoList.length,
    cryptoTotal: cryptoTotal,
    etfPositions: etfList.length,
    etfTotal: etfTotal,
    investedTotal: investedTotal,
    totalPositions: totalPositions,
    matureCount: matureCount,
    posAbove1k: posAbove1k,
    posAbove5k: posAbove5k,
    physicalCount: assetsList.length,
    physicalTotal: assetsTotal,
    physicalGoldCount: physicalGoldCount,
    physicalSilverCount: physicalSilverCount,
    physicalMetalsTotal: physicalMetalsTotal,
  );
});
