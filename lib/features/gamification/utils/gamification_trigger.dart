import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/providers/settings_providers.dart';
import '../models/gamification_models.dart';
import '../models/gamification_result.dart';
import '../providers/gamification_providers.dart';
import '../widgets/badge_toast.dart';
import '../widgets/xp_float_animation.dart';

/// Call this after a successful add/edit save (before `Navigator.pop`).
/// Runs gamification, then plays animations on the current context.
Future<void> triggerGamificationOnSave(
  BuildContext context,
  WidgetRef ref, {
  bool isFirstInCategory = false,
  String? categoryKey,
}) async {
  if (!ref.read(gamificationEnabledProvider)) return;
  final ctx = ref.read(badgeContextProvider);
  if (ctx == null || !context.mounted) return;

  final service = ref.read(gamificationServiceProvider);
  final GamificationResult result;

  if (isFirstInCategory && categoryKey != null) {
    result = await service.onFirstInCategory(
      categoryKey: categoryKey,
      ctx: ctx,
    );
  } else {
    result = await service.onRefresh(
      ctx: ctx,
      positionUpdatedThisMonth: true,
      netWorthGrewVsLastMonth: false,
    );
  }

  if (context.mounted) _playAnimations(context, ref, result);
}

/// Call this when a "I owe" debt is deleted (treated as paid off).
Future<void> triggerGamificationOnDebtPaid(
  BuildContext context,
  WidgetRef ref,
  String debtId,
) async {
  if (!ref.read(gamificationEnabledProvider)) return;
  final ctx = ref.read(badgeContextProvider);
  if (ctx == null || !context.mounted) return;

  final result = await ref
      .read(gamificationServiceProvider)
      .onDebtPaid(debtId: debtId, ctx: ctx);

  if (context.mounted) _playAnimations(context, ref, result);
}

/// Call this after a manual price refresh (home screen pull-to-refresh).
Future<void> triggerGamificationOnRefresh(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(gamificationEnabledProvider)) return;
  final ctx = ref.read(badgeContextProvider);
  if (ctx == null || !context.mounted) return;

  final result = await ref.read(gamificationServiceProvider).onRefresh(
        ctx: ctx,
        positionUpdatedThisMonth: false,
        netWorthGrewVsLastMonth: false,
      );

  if (context.mounted) _playAnimations(context, ref, result);
}

/// Call this once per session on app startup (anniversary events, longevity badges).
Future<void> triggerGamificationOnStartup(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(gamificationEnabledProvider)) return;
  final ctx = ref.read(badgeContextProvider);
  if (ctx == null || !context.mounted) return;

  final result = await ref
      .read(gamificationServiceProvider)
      .onStartup(ctx: ctx);

  if (context.mounted) _playAnimations(context, ref, result);
}

void _playAnimations(BuildContext context, WidgetRef ref, GamificationResult result) {
  if (!result.hasAnyEvent) return;
  if (result.newBadges.isNotEmpty) {
    final count = result.newBadges.length;
    ref.read(newBadgeCountProvider.notifier).add(count);
    ref.read(homeTabBadgeCountProvider.notifier).add(count);
  }
  if (result.xpGained > 0) XPFloatAnimation.show(context, result.xpGained);
  if (result.leveledUp) {
    final profile = ref.read(gamificationProfileProvider).valueOrNull;
    if (profile != null) {
      ref.read(levelUpTierProvider.notifier).state =
          LevelSystem.tierForLevel(profile.level);
    }
  }
  if (result.hasBadges) {
    GamificationOverlay.enqueue(context, result.newBadges);
  }
}
