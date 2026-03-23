import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gamification_models.dart';
import '../providers/gamification_providers.dart';
import '../widgets/badge_card.dart';
import 'mission_detail_sheet.dart';

class BadgeGridScreen extends ConsumerWidget {
  const BadgeGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(gamificationProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        title: const Text(
          'Meine Badges',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (profile) {
          final unlockedIds = profile?.unlockedBadgeIds.toSet() ?? {};
          final badgeUnlockedAt = profile?.badgeUnlockedAt ?? {};
          return _MissionGrid(
              unlockedIds: unlockedIds, badgeUnlockedAt: badgeUnlockedAt);
        },
      ),
    );
  }
}

class _MissionGrid extends StatelessWidget {
  const _MissionGrid(
      {required this.unlockedIds, required this.badgeUnlockedAt});
  final Set<String> unlockedIds;
  final Map<String, DateTime> badgeUnlockedAt;

  @override
  Widget build(BuildContext context) {
    final missionsByCategory = kMissionsByCategory;
    final categories = BadgeCategory.values;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final category = categories[i];
        final missions = missionsByCategory[category] ?? [];
        final unlockedMissions = missions
            .where((m) => m.tiers.any((t) => unlockedIds.contains(t.id)))
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryHeader(
              category: category,
              unlockedMissions: unlockedMissions,
              totalMissions: missions.length,
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              itemCount: missions.length,
              itemBuilder: (_, j) {
                final mission = missions[j];
                return MissionCard(
                  mission: mission,
                  unlockedIds: unlockedIds,
                  onTap: () => MissionDetailSheet.show(
                      context, mission, unlockedIds, badgeUnlockedAt),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.category,
    required this.unlockedMissions,
    required this.totalMissions,
  });

  final BadgeCategory category;
  final int unlockedMissions;
  final int totalMissions;

  @override
  Widget build(BuildContext context) {
    final isComplete = unlockedMissions == totalMissions;
    final progressColor = isComplete
        ? const Color(0xFFFFD700)
        : Colors.white.withOpacity(0.15);

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                category.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFFFFD700).withOpacity(0.12)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isComplete
                        ? const Color(0xFFFFD700).withOpacity(0.3)
                        : Colors.white12,
                    width: 1,
                  ),
                ),
                child: Text(
                  '$unlockedMissions/$totalMissions',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isComplete
                        ? const Color(0xFFFFD700)
                        : Colors.white.withOpacity(0.45),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: totalMissions == 0 ? 0 : unlockedMissions / totalMissions,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}
