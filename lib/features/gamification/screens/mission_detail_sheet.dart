import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/gamification_models.dart';
import '../widgets/badge_card.dart';

class MissionDetailSheet extends StatelessWidget {
  const MissionDetailSheet({
    super.key,
    required this.mission,
    required this.unlockedIds,
    required this.badgeUnlockedAt,
  });

  final BadgeMission mission;
  final Set<String> unlockedIds;
  final Map<String, DateTime> badgeUnlockedAt;

  static Future<void> show(
    BuildContext context,
    BadgeMission mission,
    Set<String> unlockedIds,
    Map<String, DateTime> badgeUnlockedAt,
  ) =>
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Badge',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, _, __) => MissionDetailSheet(
          mission: mission,
          unlockedIds: unlockedIds,
          badgeUnlockedAt: badgeUnlockedAt,
        ),
        transitionBuilder: (ctx, anim, _, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final anyUnlocked = mission.tiers.any((t) => unlockedIds.contains(t.id));
    final highest = anyUnlocked
        ? mission.tiers.reversed.firstWhere(
            (t) => unlockedIds.contains(t.id),
          )
        : null;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Blurred + dimmed background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withOpacity(0.72)),
            ),

            // Content — tap on content does NOT dismiss
            GestureDetector(
              onTap: () {}, // absorb taps so only bg tap dismisses
              child: Align(
                alignment: const Alignment(0, -0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: anyUnlocked && highest != null
                      ? _UnlockedView(
                          mission: mission,
                          badge: highest,
                          unlockedAt: badgeUnlockedAt[highest.id],
                        )
                      : _LockedView(mission: mission),
                ),
              ),
            ),

            // Dismiss hint
            const Positioned(
              bottom: 52,
              left: 0,
              right: 0,
              child: Text(
                'Tippe zum Schließen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white30,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockedView extends StatefulWidget {
  const _UnlockedView({
    required this.mission,
    required this.badge,
    this.unlockedAt,
  });
  final BadgeMission mission;
  final BadgeDefinition badge;
  final DateTime? unlockedAt;

  @override
  State<_UnlockedView> createState() => _UnlockedViewState();
}

class _UnlockedViewState extends State<_UnlockedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.badge.tier;
    final isGold = tier == GamificationTier.gold;
    final isDiamond = tier == GamificationTier.diamond;
    final showGlow = isGold || isDiamond;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Floating badge
        AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) {
            final offset = -10 * math.sin(_floatCtrl.value * math.pi);
            return Center(
              child: Transform.translate(
              offset: Offset(0, offset),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (showGlow)
                    AnimatedBuilder(
                      animation: _floatCtrl,
                      builder: (_, __) {
                        final pulse =
                            0.7 + 0.3 * math.sin(_floatCtrl.value * math.pi);
                        return Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    tier.primaryColor.withOpacity(0.6 * pulse),
                                blurRadius: 72,
                                spreadRadius: 36,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  BadgeImage(
                    missionId: widget.mission.id,
                    tier: tier,
                    fallbackEmoji: widget.mission.category.emoji,
                    size: 288,
                  ),
                ],
              ),
            ));
          },
        ),
        const SizedBox(height: 32),

        // Tier chip
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: tier.primaryColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tier.primaryColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Text(
            tier.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: tier.primaryColor,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Badge name
        Text(
          widget.badge.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),

        // Description
        Text(
          widget.badge.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.55),
            height: 1.5,
          ),
        ),

        if (widget.unlockedAt != null) ...[
          const SizedBox(height: 20),
          Text(
            'Erreicht am ${_formatDate(widget.unlockedAt!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.3),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return '${dt.day}. ${months[dt.month - 1]} ${dt.year}';
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView({required this.mission});
  final BadgeMission mission;

  @override
  Widget build(BuildContext context) {
    final firstTier = mission.tiers.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Stack(
          alignment: Alignment.center,
          children: [
            BadgeImage(
              missionId: mission.id,
              tier: GamificationTier.bronze,
              fallbackEmoji: mission.category.emoji,
              size: 288,
              opacity: 0.15,
            ),
            const Icon(
              Icons.lock,
              color: Colors.white38,
              size: 52,
            ),
          ],
        ),
        ),
        const SizedBox(height: 32),

        Text(
          mission.category.label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.3),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),

        const Text(
          'Noch gesperrt',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white38,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),

        Text(
          firstTier.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.3),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
