import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/profile_image_stub.dart'
    if (dart.library.js_interop) '../../../shared/widgets/profile_image_web.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/gamification_models.dart';
import '../providers/gamification_providers.dart';
import '../screens/profile_sidebar.dart';
import 'tier_ring.dart';

/// Avatar in the AppBar — always shows the tier ring.
/// On level-up: ring pulses with extra glow for ~5 s, and a bouncing up-arrow
/// appears to the right (between avatar and title text).
class AvatarLeading extends ConsumerStatefulWidget {
  const AvatarLeading({super.key});

  @override
  ConsumerState<AvatarLeading> createState() => _AvatarLeadingState();
}

class _AvatarLeadingState extends ConsumerState<AvatarLeading>
    with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final AnimationController _arrowCtrl;
  GamificationTier? _activeTier;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _arrowCtrl.dispose();
    super.dispose();
  }

  void _startLevelUp(GamificationTier tier) {
    if (!mounted) return;
    setState(() => _activeTier = tier);
    _glowCtrl.repeat(reverse: true);
    _arrowCtrl.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _glowCtrl
        ..stop()
        ..reset();
      _arrowCtrl
        ..stop()
        ..reset();
      setState(() => _activeTier = null);
      ref.read(levelUpTierProvider.notifier).state = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final newBadgeCount = ref.watch(newBadgeCountProvider);
    final profileAsync = ref.watch(gamificationProfileProvider);

    ref.listen<GamificationTier?>(levelUpTierProvider, (_, next) {
      if (next != null && _activeTier == null) _startLevelUp(next);
    });

    final profile = profileAsync.valueOrNull;
    final tier = profile != null
        ? LevelSystem.tierForLevel(profile.level)
        : GamificationTier.bronze;
    final level = profile?.level ?? 1;

    const double avatarRadius = 18;
    const double outerSize = 72.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Avatar area ────────────────────────────────────────────────────
        SizedBox(
          width: outerSize,
          height: outerSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Tier ring + avatar (centered, tappable)
              Positioned.fill(
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => showProfileSidebar(context),
                      customBorder: const CircleBorder(),
                      child: TierRing(
                        tier: tier,
                        level: level,
                        radius: avatarRadius,
                        strokeWidth: 2.0,
                        child: IgnorePointer(
                          child: _UserAvatar(user: user, radius: avatarRadius),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Extra level-up glow pulse overlay
              if (_activeTier != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, __) => CustomPaint(
                        painter: _LevelUpGlowPainter(
                          color: _activeTier!.primaryColor,
                          pulse: _glowCtrl.value,
                          radius: avatarRadius,
                        ),
                      ),
                    ),
                  ),
                ),

              // Bouncing up-arrow during level-up (inside the avatar area)
              if (_activeTier != null)
                Positioned(
                  right: 0,
                  top: 20,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _arrowCtrl,
                      builder: (_, __) {
                        final t = Curves.easeInOut.transform(_arrowCtrl.value);
                        return Transform.translate(
                          offset: Offset(0, -6 + 12 * t),
                          child: _LevelUpArrow(color: _activeTier!.primaryColor),
                        );
                      },
                    ),
                  ),
                ),

              // "+1" badge during level-up
              if (_activeTier != null)
                Positioned(
                  right: 2,
                  top: 2,
                  child: AnimatedBuilder(
                    animation: _glowCtrl,
                    builder: (_, __) => Opacity(
                      opacity: (0.6 + _glowCtrl.value * 0.4).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _activeTier!.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _activeTier!.primaryColor.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Text(
                          '+1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Unseen badge dot (when no level-up active)
              if (newBadgeCount > 0 && _activeTier == null)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      '$newBadgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

      ],
    );
  }
}

// ── Level-up glow painter ───────────────────────────────────────────────────

class _LevelUpGlowPainter extends CustomPainter {
  const _LevelUpGlowPainter({
    required this.color,
    required this.pulse,
    required this.radius,
  });

  final Color color;
  final double pulse; // 0.0–1.0
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Wide outer halo
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = color.withOpacity(0.28 + 0.52 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 + 8 * pulse
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Tight bright ring
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = color.withOpacity(0.20 + 0.40 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + 1.5 * pulse
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_LevelUpGlowPainter old) =>
      old.pulse != pulse || old.color != color;
}

// ── Up-arrow widget ─────────────────────────────────────────────────────────

class _LevelUpArrow extends StatelessWidget {
  const _LevelUpArrow({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow halo behind the arrow
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.18),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.65),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_upward_rounded,
            color: color,
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ── User avatar ─────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, required this.radius});
  final dynamic user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl as String?;
    final displayName = (user?.displayName as String?) ?? 'N';
    final initial = displayName.substring(0, 1).toUpperCase();

    if (photoUrl != null) {
      return ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: buildProfileImage(photoUrl, radius * 2),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1E3A5F),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
