import '../models/gamification_models.dart';

/// Net worth milestones in ascending order with their XP rewards.
const List<(double threshold, int xp, String eventId)> kNetWorthMilestones = [
  (100, 100, 'networth_100'),
  (500, 150, 'networth_500'),
  (1000, 200, 'networth_1000'),
  (2500, 300, 'networth_2500'),
  (5000, 400, 'networth_5000'),
  (10000, 600, 'networth_10000'),
  (25000, 900, 'networth_25000'),
  (50000, 1400, 'networth_50000'),
  (75000, 1800, 'networth_75000'),
  (100000, 2400, 'networth_100000'),
  (150000, 3200, 'networth_150000'),
  (250000, 5000, 'networth_250000'),
  (500000, 8000, 'networth_500000'),
  (750000, 10000, 'networth_750000'),
  (1000000, 13000, 'networth_1000000'),
];

/// Builds XP event objects. Deduplication and persistence is done by GamificationService.
class XPService {
  const XPService();

  /// Returns all net worth milestone XP events not yet awarded.
  /// Only fires if the profile was created >24h ago (deferred on first install).
  Future<List<XPEvent>> pendingNetWorthEvents({
    required double currentNetWorth,
    required GamificationProfile profile,
    required Set<String> awardedIds,
  }) async {
    final accountAge = DateTime.now().difference(profile.createdAt);
    if (accountAge.inHours < 24) return [];

    final pending = <XPEvent>[];
    for (final (threshold, xp, id) in kNetWorthMilestones) {
      if (currentNetWorth >= threshold && !awardedIds.contains(id)) {
        pending.add(XPEvent(
          id: id,
          xp: xp,
          reason: 'Nettovermögen hat €${_formatAmount(threshold)} erreicht',
          awardedAt: DateTime.now(),
        ));
      }
    }
    // Only fire the highest newly crossed milestone to avoid stacking on setup.
    return pending.isEmpty ? [] : [pending.last];
  }

  /// Builds the refresh/engagement XP event (12h cooldown, AM/PM slots).
  /// Returns null if the cooldown has not expired yet.
  XPEvent? buildRefreshEvent(Set<String> awardedIds) {
    final now = DateTime.now();
    final slot = now.hour < 12 ? 'AM' : 'PM';
    final id =
        'refresh_${now.year}-${_pad(now.month)}-${_pad(now.day)}-$slot';
    if (awardedIds.contains(id)) return null;
    return XPEvent(
      id: id,
      xp: 50,
      reason: 'App aktualisiert',
      awardedAt: now,
    );
  }

  /// Builds an event for the weekly challenge completion.
  XPEvent? buildWeeklyEvent(Set<String> awardedIds) {
    final now = DateTime.now();
    // ISO week number
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final id =
        'weekly_${weekStart.year}-${_pad(weekStart.month)}-${_pad(weekStart.day)}';
    if (awardedIds.contains(id)) return null;
    return XPEvent(
      id: id,
      xp: 50,
      reason: 'Wöchentlicher Check abgeschlossen',
      awardedAt: now,
    );
  }

  /// Builds monthly challenge events (update + positive month).
  List<XPEvent> buildMonthlyEvents({
    required bool positionUpdatedThisMonth,
    required bool netWorthGrewVsLastMonth,
    required Set<String> awardedIds,
  }) {
    final now = DateTime.now();
    final suffix = '${now.year}_${_pad(now.month)}';
    final events = <XPEvent>[];

    final updateId = 'monthly_update_$suffix';
    if (positionUpdatedThisMonth && !awardedIds.contains(updateId)) {
      events.add(XPEvent(
        id: updateId,
        xp: 75,
        reason: 'Monatliches Update abgeschlossen',
        awardedAt: now,
      ));
    }

    final growthId = 'monthly_growth_$suffix';
    if (netWorthGrewVsLastMonth && !awardedIds.contains(growthId)) {
      events.add(XPEvent(
        id: growthId,
        xp: 75,
        reason: 'Nettovermögen diesen Monat gestiegen',
        awardedAt: now,
      ));
    }

    return events;
  }

  XPEvent buildDebtPaidEvent(String debtId) => XPEvent(
        id: 'debt_paid_$debtId',
        xp: 300,
        reason: 'Schuld vollständig abbezahlt',
        awardedAt: DateTime.now(),
      );

  XPEvent buildFestgeldMaturedEvent(String festgeldId) => XPEvent(
        id: 'festgeld_matured_$festgeldId',
        xp: 100,
        reason: 'Festgeld ist fällig geworden',
        awardedAt: DateTime.now(),
      );

  XPEvent buildFirstInCategoryEvent(String categoryKey) => XPEvent(
        id: 'first_$categoryKey',
        xp: 50,
        reason: 'Erste Position in $categoryKey erfasst',
        awardedAt: DateTime.now(),
      );

  XPEvent buildAnniversaryEvent(int years) => XPEvent(
        id: 'anniversary_$years',
        xp: 500,
        reason: '$years ${years == 1 ? "Jahr" : "Jahre"} mit FinTrack',
        awardedAt: DateTime.now(),
      );

  XPEvent buildBadgeXPEvent(BadgeDefinition badge) => XPEvent(
        id: 'badge_xp_${badge.id}',
        xp: badge.xpReward,
        reason: 'Badge freigeschaltet: ${badge.name}',
        awardedAt: DateTime.now(),
      );

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(0)} Mio.';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
    return amount.toStringAsFixed(0);
  }
}
