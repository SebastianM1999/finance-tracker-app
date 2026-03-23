import '../data/gamification_repository.dart';
import '../models/gamification_models.dart';
import 'badge_service.dart';
import 'challenge_service.dart';
import 'xp_service.dart';

/// Central orchestrator. Call one of the `on*` methods after a user action.
/// Returns a [GamificationResult] that drives the animation sequence.
class GamificationService {
  GamificationService({
    required GamificationRepository repository,
    required XPService xpService,
    required BadgeService badgeService,
    required ChallengeService challengeService,
  })  : _repo = repository,
        _xp = xpService,
        _badges = badgeService,
        _challenges = challengeService;

  final GamificationRepository _repo;
  final XPService _xp;
  final BadgeService _badges;
  final ChallengeService _challenges;

  // ── Public event handlers ────────────────────────────────────────────────

  /// Called when the user refreshes the home screen or edits/adds a position.
  Future<GamificationResult> onRefresh({
    required BadgeContext ctx,
    required bool positionUpdatedThisMonth,
    required bool netWorthGrewVsLastMonth,
  }) async {
    final profile = await _repo.ensureProfile();
    final awardedIds = await _repo.fetchAwardedEventIds();

    final events = <XPEvent>[];

    // Refresh slot (12h cooldown)
    final refreshEvent = _xp.buildRefreshEvent(awardedIds);
    if (refreshEvent != null) {
      events.add(refreshEvent);
      await _repo.incrementUpdateCount();
    }

    // Weekly challenge
    final weeklyEvent = _xp.buildWeeklyEvent(awardedIds);
    if (weeklyEvent != null) events.add(weeklyEvent);

    // Monthly challenges
    events.addAll(_xp.buildMonthlyEvents(
      positionUpdatedThisMonth: positionUpdatedThisMonth,
      netWorthGrewVsLastMonth: netWorthGrewVsLastMonth,
      awardedIds: awardedIds,
    ));

    // Net worth milestones
    final updatedAwardedIds = {...awardedIds, ...events.map((e) => e.id)};
    events.addAll(await _xp.pendingNetWorthEvents(
      currentNetWorth: ctx.netWorth,
      profile: profile,
      awardedIds: updatedAwardedIds,
    ));

    return _apply(profile: profile, events: events, ctx: ctx);
  }

  /// Called when a category gets its first ever position.
  Future<GamificationResult> onFirstInCategory({
    required String categoryKey,
    required BadgeContext ctx,
  }) async {
    final profile = await _repo.ensureProfile();
    final awardedIds = await _repo.fetchAwardedEventIds();

    final events = <XPEvent>[];
    final firstEvent = _xp.buildFirstInCategoryEvent(categoryKey);
    if (!awardedIds.contains(firstEvent.id)) events.add(firstEvent);

    return _apply(profile: profile, events: events, ctx: ctx);
  }

  /// Called when a debt is fully paid off (user deletes it as "paid").
  Future<GamificationResult> onDebtPaid({
    required String debtId,
    required BadgeContext ctx,
  }) async {
    final profile = await _repo.ensureProfile();
    final awardedIds = await _repo.fetchAwardedEventIds();

    final events = <XPEvent>[];
    final event = _xp.buildDebtPaidEvent(debtId);
    if (!awardedIds.contains(event.id)) {
      events.add(event);
      await _repo.incrementPaidOffDebts();
    }

    return _apply(profile: profile, events: events, ctx: ctx);
  }

  /// Called when a Festgeld matures.
  Future<GamificationResult> onFestgeldMatured({
    required String festgeldId,
    required BadgeContext ctx,
  }) async {
    final profile = await _repo.ensureProfile();
    final awardedIds = await _repo.fetchAwardedEventIds();

    final events = <XPEvent>[];
    final event = _xp.buildFestgeldMaturedEvent(festgeldId);
    if (!awardedIds.contains(event.id)) {
      events.add(event);
      await _repo.incrementMatureCount();
    }

    // Complete the one-time challenge too
    final completedChallenges = <ChallengeDefinition>[];
    if (!profile.hasChallenge('festgeld_matured')) {
      completedChallenges.add(kChallengeById['festgeld_matured']!);
      final challengeEvent = XPEvent(
        id: 'challenge_festgeld_matured',
        xp: 200,
        reason: 'Herausforderung abgeschlossen: Erste Fälligkeit',
        awardedAt: DateTime.now(),
      );
      if (!awardedIds.contains(challengeEvent.id)) events.add(challengeEvent);
    }

    return _apply(
      profile: profile,
      events: events,
      ctx: ctx,
      extraChallenges: completedChallenges,
    );
  }

  /// Called on app startup to award time-based events (anniversaries, longevity badges).
  Future<GamificationResult> onStartup({required BadgeContext ctx}) async {
    final profile = await _repo.ensureProfile();
    final awardedIds = await _repo.fetchAwardedEventIds();

    final events = <XPEvent>[];
    final age = DateTime.now().difference(profile.createdAt);

    for (final years in [1, 2, 3]) {
      if (age.inDays >= years * 365) {
        final event = _xp.buildAnniversaryEvent(years);
        if (!awardedIds.contains(event.id)) events.add(event);
      }
    }

    return _apply(profile: profile, events: events, ctx: ctx);
  }

  // ── Core apply logic ─────────────────────────────────────────────────────

  Future<GamificationResult> _apply({
    required GamificationProfile profile,
    required List<XPEvent> events,
    required BadgeContext ctx,
    List<ChallengeDefinition> extraChallenges = const [],
  }) async {
    if (events.isEmpty && extraChallenges.isEmpty) {
      // Still check for badge unlocks — they carry their own XP
      final newBadges = _badges.evaluate(profile: profile, ctx: ctx);
      if (newBadges.isEmpty) return GamificationResult.empty;
      final badgeEvents = newBadges.map(_xp.buildBadgeXPEvent).toList();
      return _persistAndBuild(
        profile: profile,
        events: badgeEvents,
        newBadges: newBadges,
        completedChallenges: const [],
      );
    }

    // Badge XP events come on top
    final updatedProfile = profile.copyWith(
      updateCount: profile.updateCount,
    );
    final newBadges = _badges.evaluate(profile: updatedProfile, ctx: ctx);

    final badgeEvents = newBadges.map(_xp.buildBadgeXPEvent).toList();

    final permanentChallenges = _challenges.evaluatePermanent(
      profile: updatedProfile,
      ctx: ctx,
    );
    final allChallenges = [...permanentChallenges, ...extraChallenges];

    final allEvents = [...events, ...badgeEvents];

    return _persistAndBuild(
      profile: profile,
      events: allEvents,
      newBadges: newBadges,
      completedChallenges: allChallenges,
    );
  }

  Future<GamificationResult> _persistAndBuild({
    required GamificationProfile profile,
    required List<XPEvent> events,
    required List<BadgeDefinition> newBadges,
    required List<ChallengeDefinition> completedChallenges,
  }) async {
    final xpGained = events.fold<int>(0, (sum, e) => sum + e.xp);
    final previousLevel = profile.level;
    final newTotalXP = profile.totalXP + xpGained;
    final newLevel = LevelSystem.levelFromXP(newTotalXP);

    if (events.isNotEmpty) {
      await _repo.recordXPEvents(events);
    }

    if (xpGained > 0 || newBadges.isNotEmpty || completedChallenges.isNotEmpty) {
      await _repo.incrementXP(
        xp: xpGained,
        newLevel: newLevel,
        newBadgeIds: newBadges.map((b) => b.id).toList(),
        newChallengeIds: completedChallenges.map((c) => c.id).toList(),
      );
    }

    return GamificationResult(
      xpGained: xpGained,
      previousLevel: previousLevel,
      newLevel: newLevel,
      previousTier: LevelSystem.tierForLevel(previousLevel),
      newBadges: newBadges,
      completedChallenges: completedChallenges,
    );
  }
}
