import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gamification_models.dart';

/// Loads `assets/badges/{missionId}_{tier}.png` if the file exists,
/// otherwise renders the [fallbackEmoji] at the equivalent size.
class BadgeImage extends StatelessWidget {
  const BadgeImage({
    super.key,
    required this.missionId,
    required this.tier,
    required this.fallbackEmoji,
    this.size = 48,
    this.opacity = 1.0,
  });

  final String missionId;
  final GamificationTier tier;
  final String fallbackEmoji;
  final double size;
  final double opacity;

  String get _assetPath => 'assets/badges/${missionId}_${tier.name}.png';

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            fallbackEmoji,
            style: TextStyle(fontSize: size * 0.55),
          ),
        ),
      ),
    );
    if (opacity < 1.0) img = Opacity(opacity: opacity, child: img);
    return img;
  }
}

class MissionCard extends StatefulWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.unlockedIds,
    this.onTap,
  });

  final BadgeMission mission;
  final Set<String> unlockedIds;
  final VoidCallback? onTap;

  @override
  State<MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<MissionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idleCtrl;

  BadgeDefinition? get _highestUnlocked {
    for (final tier in widget.mission.tiers.reversed) {
      if (widget.unlockedIds.contains(tier.id)) return tier;
    }
    return null;
  }

  bool get _hasIdleAnim {
    final h = _highestUnlocked;
    return h != null &&
        (h.tier == GamificationTier.gold || h.tier == GamificationTier.diamond);
  }

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: _highestUnlocked?.tier == GamificationTier.diamond
          ? const Duration(seconds: 4)
          : const Duration(seconds: 3),
    );
    if (_hasIdleAnim) _idleCtrl.repeat();
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highest = _highestUnlocked;
    if (highest == null) return _buildLocked();

    return GestureDetector(
      onTap: widget.onTap,
      child: _hasIdleAnim
          ? AnimatedBuilder(
              animation: _idleCtrl,
              builder: (_, __) => _buildUnlocked(highest, _idleCtrl.value),
            )
          : _buildUnlocked(highest, 0),
    );
  }

  Widget _buildLocked() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              BadgeImage(
                missionId: widget.mission.id,
                tier: GamificationTier.bronze,
                fallbackEmoji: widget.mission.category.emoji,
                size: 86,
                opacity: 0.15,
              ),
              const Icon(
                Icons.lock,
                color: Colors.white38,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TierDots(mission: widget.mission, unlockedIds: widget.unlockedIds),
        ],
      ),
    );
  }

  Widget _buildUnlocked(BadgeDefinition highest, double idleValue) {
    final isDiamond = highest.tier == GamificationTier.diamond;
    final isGold = highest.tier == GamificationTier.gold;

    double pulse = 1.0;
    if (isDiamond) {
      pulse = 0.85 + 0.15 * math.sin(idleValue * 2 * math.pi);
    } else if (isGold) {
      pulse = 0.7 + 0.3 * math.sin(idleValue * 2 * math.pi);
    }

    Widget badgeWidget = BadgeImage(
      missionId: widget.mission.id,
      tier: highest.tier,
      fallbackEmoji: widget.mission.category.emoji,
      size: 86,
      opacity: pulse,
    );

    if (isGold || isDiamond) {
      badgeWidget = Stack(
        alignment: Alignment.center,
        children: [
          // Glow halo behind the badge
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: highest.tier.primaryColor.withOpacity(0.55 * pulse),
                  blurRadius: 28,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          BadgeImage(
            missionId: widget.mission.id,
            tier: highest.tier,
            fallbackEmoji: widget.mission.category.emoji,
            size: 86,
            opacity: pulse,
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badgeWidget,
        const SizedBox(height: 8),
        Text(
          highest.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        _TierDots(mission: widget.mission, unlockedIds: widget.unlockedIds),
      ],
    );
  }
}

class _TierDots extends StatelessWidget {
  const _TierDots({required this.mission, required this.unlockedIds});
  final BadgeMission mission;
  final Set<String> unlockedIds;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: mission.tiers.map((tier) {
        final isUnlocked = unlockedIds.contains(tier.id);
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked ? tier.tier.primaryColor : Colors.white12,
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: tier.tier.primaryColor.withOpacity(0.6),
                      blurRadius: 4,
                    )
                  ]
                : null,
          ),
        );
      }).toList(),
    );
  }
}
