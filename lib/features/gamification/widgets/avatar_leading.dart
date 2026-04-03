import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/profile_image_stub.dart'
    if (dart.library.js_interop) '../../../shared/widgets/profile_image_web.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/gamification_tier.dart';
import '../providers/gamification_providers.dart';
import '../screens/profile_sidebar.dart';
import 'tier_ring.dart';

/// Avatar in the AppBar — tappable to open the profile sidebar.
/// Shows a red badge dot when new badges have been unlocked.
class AvatarLeading extends ConsumerWidget {
  const AvatarLeading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final newBadgeCount = ref.watch(newBadgeCountProvider);
    final profile = ref.watch(gamificationProfileProvider).valueOrNull;
    final tier = profile?.playerTier ?? GamificationTier.bronze;

    const double avatarRadius = 18;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => showProfileSidebar(context),
                  customBorder: const CircleBorder(),
                  child: TierRing(
                    tier: tier,
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

          // Unseen badge dot
          if (newBadgeCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
