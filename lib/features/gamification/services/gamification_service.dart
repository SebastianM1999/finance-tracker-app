import '../data/gamification_repository.dart';
import '../models/gamification_models.dart';
import 'badge_service.dart';

/// Central orchestrator. Call one of the `on*` methods after a user action.
/// Returns a [GamificationResult] that drives the badge toast animation.
class GamificationService {
  GamificationService({
    required GamificationRepository repository,
    required BadgeService badgeService,
  })  : _repo = repository,
        _badges = badgeService;

  final GamificationRepository _repo;
  final BadgeService _badges;

  // ── Public event handlers ────────────────────────────────────────────────

  /// Called when the user refreshes the home screen or edits/adds a position.
  /// updateCount only increments once per 12 hours to prevent spam.
  Future<GamificationResult> onRefresh({required BadgeContext ctx}) async {
    final profile = await _repo.ensureProfile();
    final last = profile.lastUpdateCountedAt;
    final cooldownPassed = last == null ||
        DateTime.now().difference(last) >= const Duration(hours: 12);
    if (cooldownPassed) await _repo.incrementUpdateCount();
    return _applyBadges(profile: profile, ctx: ctx);
  }

  /// Called when a category gets its first ever position.
  Future<GamificationResult> onFirstInCategory({
    required String categoryKey,
    required BadgeContext ctx,
  }) async {
    final profile = await _repo.ensureProfile();
    return _applyBadges(profile: profile, ctx: ctx);
  }

  /// Called when a debt is fully paid off (user deletes it as "paid").
  Future<GamificationResult> onDebtPaid({
    required String debtId,
    required BadgeContext ctx,
  }) async {
    final profile = await _repo.ensureProfile();
    await _repo.incrementPaidOffDebts();
    return _applyBadges(profile: profile, ctx: ctx);
  }

  /// Called when a Festgeld matures.
  Future<GamificationResult> onFestgeldMatured({
    required String festgeldId,
    required BadgeContext ctx,
  }) async {
    final profile = await _repo.ensureProfile();
    await _repo.incrementMatureCount();
    return _applyBadges(profile: profile, ctx: ctx);
  }

  /// Called on app startup.
  Future<GamificationResult> onStartup({required BadgeContext ctx}) async {
    final profile = await _repo.ensureProfile();
    return _applyBadges(profile: profile, ctx: ctx);
  }

  // ── Core apply logic ─────────────────────────────────────────────────────

  Future<GamificationResult> _applyBadges({
    required GamificationProfile profile,
    required BadgeContext ctx,
  }) async {
    final newBadges = _badges.evaluate(profile: profile, ctx: ctx);
    if (newBadges.isEmpty) return GamificationResult.empty;

    await _repo.awardBadges(
      newBadgeIds: newBadges.map((b) => b.id).toList(),
    );

    return GamificationResult(newBadges: newBadges);
  }
}
