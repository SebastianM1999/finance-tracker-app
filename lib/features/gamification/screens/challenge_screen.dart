import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gamification_models.dart';
import '../providers/gamification_providers.dart';

class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(gamificationProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        title: const Text(
          'Herausforderungen',
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
          final completedIds = profile?.completedChallengeIds.toSet() ?? {};
          return _ChallengeList(completedIds: completedIds);
        },
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  const _ChallengeList({required this.completedIds});
  final Set<String> completedIds;

  List<Widget> _buildGroup({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<ChallengeDefinition> challenges,
  }) {
    final incomplete = challenges.where((c) => !completedIds.contains(c.id)).toList();
    if (incomplete.isEmpty) return [];
    return [
      _SectionHeader(title: title, subtitle: subtitle, icon: icon),
      ...incomplete.map((c) => _ChallengeRow(challenge: c, isCompleted: false)),
      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allCompleted = [
      ...kPermanentChallenges,
      ...kWeeklyChallenges,
      ...kMonthlyChallenges,
    ].where((c) => completedIds.contains(c.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ..._buildGroup(
          title: 'Dauerhaft',
          subtitle: 'Einmalig erreichbar',
          icon: Icons.emoji_events_outlined,
          challenges: kPermanentChallenges,
        ),
        ..._buildGroup(
          title: 'Wöchentlich',
          subtitle: 'Setzt sich jeden Montag zurück',
          icon: Icons.calendar_today_outlined,
          challenges: kWeeklyChallenges,
        ),
        ..._buildGroup(
          title: 'Monatlich',
          subtitle: 'Setzt sich am 1. zurück',
          icon: Icons.date_range_outlined,
          challenges: kMonthlyChallenges,
        ),
        if (allCompleted.isNotEmpty) ...[
          _SectionHeader(
            title: 'Abgeschlossen',
            subtitle: '${allCompleted.length} erledigt',
            icon: Icons.check_circle_outline,
          ),
          ...allCompleted.map((c) => _ChallengeRow(challenge: c, isCompleted: true)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.challenge, required this.isCompleted});
  final ChallengeDefinition challenge;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF1A2A1A)
            : const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : Colors.white24,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  challenge.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.35),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${challenge.xpReward} XP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: isCompleted
                  ? Colors.white.withOpacity(0.3)
                  : const Color(0xFFD4A017),
            ),
          ),
        ],
      ),
    );
  }
}
