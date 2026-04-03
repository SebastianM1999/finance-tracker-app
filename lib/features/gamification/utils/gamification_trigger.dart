import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/providers/settings_providers.dart';
import '../models/gamification_models.dart';
import '../providers/gamification_providers.dart';
import '../services/badge_service.dart';
import '../widgets/badge_toast.dart';

Future<void> triggerGamificationOnSave(
  BuildContext context,
  WidgetRef ref, {
  bool isFirstInCategory = false,
  String? categoryKey,
}) async {
  if (!context.mounted) return;
  GamificationOverlay.registerOverlay(context);
  final container = ProviderScope.containerOf(context);

  if (!container.read(gamificationEnabledProvider)) return;
  final ctx = await _awaitBadgeContext(container);
  if (ctx == null) return;

  final result = isFirstInCategory && categoryKey != null
      ? await container.read(gamificationServiceProvider).onFirstInCategory(
            categoryKey: categoryKey,
            ctx: ctx,
          )
      : await container.read(gamificationServiceProvider).onRefresh(ctx: ctx);

  _playAnimations(container, result);
}

Future<void> triggerGamificationOnDebtPaid(
  BuildContext context,
  WidgetRef ref,
  String debtId,
) async {
  if (!context.mounted) return;
  GamificationOverlay.registerOverlay(context);
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
  GamificationOverlay.registerOverlay(context);
  final container = ProviderScope.containerOf(context);

  if (!container.read(gamificationEnabledProvider)) return;
  final ctx = await _awaitBadgeContext(container);
  if (ctx == null) return;

  final result =
      await container.read(gamificationServiceProvider).onRefresh(ctx: ctx);

  _playAnimations(container, result);
}

Future<void> triggerGamificationOnStartup(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted) return;
  GamificationOverlay.registerOverlay(context);
  final container = ProviderScope.containerOf(context);

  if (!container.read(gamificationEnabledProvider)) return;
  final ctx = await _awaitBadgeContext(container);
  if (ctx == null) return;

  final result =
      await container.read(gamificationServiceProvider).onStartup(ctx: ctx);

  _playAnimations(container, result);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
    GamificationOverlay.enqueueFromOverlay(result.newBadges);
  }
}
