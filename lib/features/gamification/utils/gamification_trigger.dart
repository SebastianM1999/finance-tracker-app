import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/providers/settings_providers.dart';
import '../models/gamification_models.dart';
import '../services/badge_service.dart';
import '../models/gamification_result.dart';
import '../providers/gamification_providers.dart';
import '../widgets/badge_toast.dart';
import '../widgets/xp_float_animation.dart';

Future<void> triggerGamificationOnSave(
  BuildContext context,
  WidgetRef ref, {
  bool isFirstInCategory = false,
  String? categoryKey,
}) async {
  if (!context.mounted) return;
  // Capture stable refs FIRST — before any await or null checks.
  _registerOverlays(context);
  final container = ProviderScope.containerOf(context);

  if (!container.read(gamificationEnabledProvider)) return;
  final ctx = await _awaitBadgeContext(container);
  if (ctx == null) return;

  final GamificationResult result;
  if (isFirstInCategory && categoryKey != null) {
    result = await container.read(gamificationServiceProvider).onFirstInCategory(
          categoryKey: categoryKey,
          ctx: ctx,
        );
  } else {
    result = await container.read(gamificationServiceProvider).onRefresh(
          ctx: ctx,
          positionUpdatedThisMonth: true,
          netWorthGrewVsLastMonth: false,
        );
  }

  _playAnimations(container, result);
}

Future<void> triggerGamificationOnDebtPaid(
  BuildContext context,
  WidgetRef ref,
  String debtId,
) async {
  if (!context.mounted) return;
  _registerOverlays(context);
  final container = ProviderScope.containerOf(context);

  if (!container.read(gamificationEnabledProvider)) return;
  final ctx = await _awaitBadgeContext(container);
  if (ctx == null) return;

  final result = await container
      .read(gamificationServiceProvider)
      .onDebtPaid(debtId: debtId, ctx: ctx);

  _playAnimations(container, result);
}

Future<void> triggerGamificationOnRefresh(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted) return;
  _registerOverlays(context);
  final container = ProviderScope.containerOf(context);

  if (!container.read(gamificationEnabledProvider)) return;
  final ctx = await _awaitBadgeContext(container);
  if (ctx == null) return;

  final result = await container.read(gamificationServiceProvider).onRefresh(
        ctx: ctx,
        positionUpdatedThisMonth: false,
        netWorthGrewVsLastMonth: false,
      );

  _playAnimations(container, result);
}

Future<void> triggerGamificationOnStartup(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted) return;
  _registerOverlays(context);
  final container = ProviderScope.containerOf(context);

  if (!container.read(gamificationEnabledProvider)) return;
  final ctx = await _awaitBadgeContext(container);
  if (ctx == null) return;

  final result =
      await container.read(gamificationServiceProvider).onStartup(ctx: ctx);

  _playAnimations(container, result);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

void _registerOverlays(BuildContext context) {
  XPFloatAnimation.registerOverlay(context);
  GamificationOverlay.registerOverlay(context);
}

/// Waits up to ~3 s for all data streams to emit their first value.
/// Returns null only if streams never load (offline / error).
Future<BadgeContext?> _awaitBadgeContext(
  ProviderContainer container, {
  int maxAttempts = 10,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    final ctx = container.read(badgeContextProvider);
    if (ctx != null) return ctx;
    await Future.delayed(const Duration(milliseconds: 300));
  }
  return null;
}

void _playAnimations(ProviderContainer container, GamificationResult result) {
  if (!result.hasAnyEvent) return;

  if (result.newBadges.isNotEmpty) {
    final count = result.newBadges.length;
    container.read(newBadgeCountProvider.notifier).add(count);
    container.read(homeTabBadgeCountProvider.notifier).add(count);
  }

  if (result.xpGained > 0) XPFloatAnimation.showFromOverlay(result.xpGained);

  if (result.leveledUp) {
    final profile = container.read(gamificationProfileProvider).valueOrNull;
    if (profile != null) {
      container.read(levelUpTierProvider.notifier).state =
          LevelSystem.tierForLevel(profile.level);
    }
  }

  if (result.hasBadges) {
    GamificationOverlay.enqueueFromOverlay(result.newBadges);
  }
}
