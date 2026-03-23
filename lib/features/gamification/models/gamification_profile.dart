import 'package:cloud_firestore/cloud_firestore.dart';

import 'gamification_tier.dart';
import 'level_system.dart';

/// Stored at users/{uid}/gamification/profile
class GamificationProfile {
  const GamificationProfile({
    required this.totalXP,
    required this.level,
    required this.unlockedBadgeIds,
    required this.completedChallengeIds,
    required this.updateCount,
    required this.paidOffDebts,
    required this.matureCount,
    required this.createdAt,
    required this.lastCheckedAt,
    this.badgeUnlockedAt = const {},
  });

  final int totalXP;
  final int level;
  final List<String> unlockedBadgeIds;
  final List<String> completedChallengeIds;
  final int updateCount;

  /// Total number of debts the user has ever marked as paid (via onDebtPaid).
  final int paidOffDebts;

  /// Total number of Festgelder that have matured (via onFestgeldMatured).
  final int matureCount;

  final DateTime createdAt;
  final DateTime lastCheckedAt;

  /// When each badge was first unlocked. Key = badge ID, value = unlock time.
  final Map<String, DateTime> badgeUnlockedAt;

  GamificationTier get tier => LevelSystem.tierForLevel(level);
  int get xpIntoLevel => LevelSystem.xpIntoCurrentLevel(totalXP);
  double get levelProgress => LevelSystem.levelProgress(totalXP);

  bool hasBadge(String badgeId) => unlockedBadgeIds.contains(badgeId);
  bool hasChallenge(String challengeId) =>
      completedChallengeIds.contains(challengeId);

  static GamificationProfile empty(DateTime createdAt) => GamificationProfile(
        totalXP: 0,
        level: 1,
        unlockedBadgeIds: [],
        completedChallengeIds: [],
        updateCount: 0,
        paidOffDebts: 0,
        matureCount: 0,
        createdAt: createdAt,
        lastCheckedAt: createdAt,
      );

  factory GamificationProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GamificationProfile(
      totalXP: (d['totalXP'] as num?)?.toInt() ?? 0,
      level: (d['level'] as num?)?.toInt() ?? 1,
      unlockedBadgeIds:
          (d['unlockedBadgeIds'] as List<dynamic>?)?.cast<String>() ?? [],
      completedChallengeIds:
          (d['completedChallengeIds'] as List<dynamic>?)?.cast<String>() ?? [],
      updateCount: (d['updateCount'] as num?)?.toInt() ?? 0,
      paidOffDebts: (d['paidOffDebts'] as num?)?.toInt() ?? 0,
      matureCount: (d['matureCount'] as num?)?.toInt() ?? 0,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastCheckedAt: d['lastCheckedAt'] != null
          ? (d['lastCheckedAt'] as Timestamp).toDate()
          : DateTime.now(),
      badgeUnlockedAt:
          (d['badgeUnlockedAt'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as Timestamp).toDate()),
              ) ??
              {},
    );
  }

  Map<String, dynamic> toFirestore() => {
        'totalXP': totalXP,
        'level': level,
        'unlockedBadgeIds': unlockedBadgeIds,
        'completedChallengeIds': completedChallengeIds,
        'updateCount': updateCount,
        'paidOffDebts': paidOffDebts,
        'matureCount': matureCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastCheckedAt': Timestamp.fromDate(lastCheckedAt),
        'badgeUnlockedAt': badgeUnlockedAt
            .map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      };

  GamificationProfile copyWith({
    int? totalXP,
    int? level,
    List<String>? unlockedBadgeIds,
    List<String>? completedChallengeIds,
    int? updateCount,
    int? paidOffDebts,
    int? matureCount,
    DateTime? lastCheckedAt,
    Map<String, DateTime>? badgeUnlockedAt,
  }) =>
      GamificationProfile(
        totalXP: totalXP ?? this.totalXP,
        level: level ?? this.level,
        unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
        completedChallengeIds:
            completedChallengeIds ?? this.completedChallengeIds,
        updateCount: updateCount ?? this.updateCount,
        paidOffDebts: paidOffDebts ?? this.paidOffDebts,
        matureCount: matureCount ?? this.matureCount,
        createdAt: createdAt,
        lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
        badgeUnlockedAt: badgeUnlockedAt ?? this.badgeUnlockedAt,
      );
}
