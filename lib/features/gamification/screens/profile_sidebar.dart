import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/profile_image_stub.dart'
    if (dart.library.js_interop) '../../../shared/widgets/profile_image_web.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/badge_definition.dart';
import '../models/gamification_models.dart';
import '../providers/gamification_providers.dart';
import '../widgets/tier_ring.dart';
import '../../../core/router/app_router.dart';
import '../../markt/screens/markt_screen.dart';
import '../../tools/screens/sparrechner_screen.dart';
import '../../tools/screens/zinsrechner_screen.dart';
import '../../watchlist/screens/watchlist_screen.dart';
import 'badge_grid_screen.dart';
import 'challenge_screen.dart';
import 'stats_screen.dart';

/// Opens the profile sidebar as a left-side drawer.
Future<void> showProfileSidebar(BuildContext context) => showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, _) => const _ProfileSidebarPage(),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );

class _ProfileSidebarPage extends ConsumerWidget {
  const _ProfileSidebarPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(gamificationProfileProvider);

    final photoUrl = user?.photoUrl;
    final displayName = user?.displayName ?? 'Nutzer';
    final initial = displayName.substring(0, 1).toUpperCase();

    final newBadgeCount = ref.watch(newBadgeCountProvider);

    final profile = profileAsync.valueOrNull;
    final tier = profile != null
        ? LevelSystem.tierForLevel(profile.level)
        : GamificationTier.bronze;
    final level = profile?.level ?? 1;
    final totalXP = profile?.totalXP ?? 0;
    final progress = LevelSystem.levelProgress(totalXP);
    final unlockedIds = profile?.unlockedBadgeIds.toSet() ?? <String>{};
    final unlockedCount = kAllBadges
        .where((b) => unlockedIds.contains(b.id))
        .map((b) => b.missionId)
        .toSet()
        .length;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.82,
          height: double.infinity,
          color: const Color(0xFF0D0F14),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button top-right inside sidebar
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),

                // Profile header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Row(
                    children: [
                      // Avatar with tier ring
                      TierRing(
                        tier: tier,
                        level: level,
                        radius: 26,
                        strokeWidth: 2.5,
                        child: photoUrl != null
                            ? ClipOval(
                                child: SizedBox.square(
                                  dimension: 52,
                                  child: buildProfileImage(photoUrl, 52),
                                ),
                              )
                            : CircleAvatar(
                                radius: 26,
                                backgroundColor: AppColors.darkPrimary,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName.split(' ').first,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                // Tier chip — same style as badge toast
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tier.primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: tier.primaryColor.withOpacity(0.45),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    tier.label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: tier.primaryColor,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Level $level',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: tier.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // XP bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor:
                              AlwaysStoppedAnimation(tier.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$totalXP XP',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                          if (level < LevelSystem.maxLevel)
                            Text(
                              'Nächstes Level: ${LevelSystem.xpToNextLevel(totalXP)} XP',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                const Divider(color: Colors.white10, height: 1),

                // Scrollable menu area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                // Group: Gaming
                const _SectionHeader(label: 'Errungenschaften'),
                _MenuItem(
                  icon: Icons.military_tech_outlined,
                  title: 'Meine Badges',
                  trailing: '$unlockedCount/26',
                  badgeCount: newBadgeCount,
                  onTap: () {
                    ref.read(newBadgeCountProvider.notifier).clear();
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.92,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, ctrl) => const BadgeGridScreen(),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.bolt_outlined,
                  title: 'Herausforderungen',
                  trailing: null,
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.92,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, ctrl) => const ChallengeScreen(),
                      ),
                    );
                  },
                ),

                const Divider(color: Colors.white10, height: 1),

                // Group: Finance stats
                const _SectionHeader(label: 'Statistiken'),
                _MenuItem(
                  icon: Icons.show_chart_outlined,
                  title: 'Vermögensentwicklung',
                  trailing: null,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.verlauf);
                  },
                ),
                _MenuItem(
                  icon: Icons.bar_chart_outlined,
                  title: 'Meine Statistiken',
                  trailing: null,
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.92,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, ctrl) => const StatsScreen(),
                      ),
                    );
                  },
                ),

                const Divider(color: Colors.white10, height: 1),

                // Group: Tools
                const _SectionHeader(label: 'Werkzeuge'),
                _MenuItem(
                  icon: Icons.calculate_outlined,
                  title: 'Zinsrechner',
                  trailing: null,
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.92,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, ctrl) =>
                            ZinsrechnerScreen(scrollController: ctrl),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.trending_up_outlined,
                  title: 'Sparrechner',
                  trailing: null,
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.92,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, ctrl) =>
                            SparrechnerScreen(scrollController: ctrl),
                      ),
                    );
                  },
                ),

                const Divider(color: Colors.white10, height: 1),

                // Group: Markt
                const _SectionHeader(label: 'Markt'),
                _MenuItem(
                  icon: Icons.bar_chart_outlined,
                  title: 'Top Performer',
                  trailing: null,
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.92,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, ctrl) =>
                            MarktScreen(scrollController: ctrl),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.visibility_outlined,
                  title: 'Watchlist',
                  trailing: null,
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.92,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, ctrl) => const WatchlistScreen(),
                      ),
                    );
                  },
                ),

                      ],
                    ),
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                _MenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Einstellungen',
                  trailing: null,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/settings');
                  },
                ),

                const Divider(color: Colors.white10, height: 1),

                // Sign out
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                  leading: const Icon(Icons.logout,
                      color: Colors.redAccent, size: 22),
                  title: const Text(
                    'Abmelden',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref.read(authRepositoryProvider).signOut();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.3),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badgeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.2),
            size: 18,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
