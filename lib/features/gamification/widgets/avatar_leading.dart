import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/profile_image_stub.dart'
    if (dart.library.js_interop) '../../../shared/widgets/profile_image_web.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/gamification_models.dart';
import '../providers/gamification_providers.dart';
import '../screens/profile_sidebar.dart';

/// Avatar in the AppBar leading/actions slot.
/// No tier ring — ring is only shown in the profile sidebar.
/// Watches [levelUpTierProvider] — when set, pulses the avatar and shows a "+1"
/// badge in the tier colour for ~2.5 s, then clears the signal.
class AvatarLeading extends ConsumerStatefulWidget {
  const AvatarLeading({super.key});

  @override
  ConsumerState<AvatarLeading> createState() => _AvatarLeadingState();
}

class _AvatarLeadingState extends ConsumerState<AvatarLeading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  GamificationTier? _activeTier;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startPulse(GamificationTier tier) {
    _activeTier = tier;
    _pulseCtrl.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      _pulseCtrl.stop();
      _pulseCtrl.animateTo(0);
      setState(() => _activeTier = null);
      ref.read(levelUpTierProvider.notifier).state = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final newBadgeCount = ref.watch(newBadgeCountProvider);

    ref.listen<GamificationTier?>(levelUpTierProvider, (_, next) {
      if (next != null && _activeTier == null) _startPulse(next);
    });

    const double avatarRadius = 18;
    const double outerSize = avatarRadius * 2 + 16;

    return Center(
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => showProfileSidebar(context),
                    customBorder: const CircleBorder(),
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _scaleAnim,
                        builder: (_, child) => Transform.scale(
                          scale: _scaleAnim.value,
                          child: child,
                        ),
                        child: _UserAvatar(user: user, radius: avatarRadius),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // "+1" level-up badge
            if (_activeTier != null)
              Positioned(
                right: 0,
                top: 0,
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Opacity(
                    opacity: (0.6 + _pulseCtrl.value * 0.4).clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _activeTier!.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.black, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _activeTier!.primaryColor
                                .withOpacity(0.6),
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

            // Unseen badge dot
            if (newBadgeCount > 0 && _activeTier == null)
              Positioned(
                right: 0,
                top: 0,
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
    );
  }
}

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
