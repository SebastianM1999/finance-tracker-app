import 'package:cloud_firestore/cloud_firestore.dart';

import 'badge_definition.dart';
import 'gamification_tier.dart';

/// Stored at users/{uid}/gamification/profile
class GamificationProfile {
  const GamificationProfile({
    required this.unlockedBadgeIds,
    required this.updateCount,
    required this.paidOffDebts,
    required this.matureCount,
    required this.createdAt,
    required this.lastCheckedAt,
    this.lastUpdateCountedAt,
    this.badgeUnlockedAt = const {},
  });

  final List<String> unlockedBadgeIds;
  final int updateCount;

  /// Total number of debts the user has ever marked as paid (via onDebtPaid).
  final int paidOffDebts;

  /// Total number of Festgelder that have matured (via onFestgeldMatured).
  final int matureCount;

  final DateTime createdAt;
  final DateTime lastCheckedAt;

  /// Last time updateCount was incremented — used to enforce the 12h cooldown.
  final DateTime? lastUpdateCountedAt;

  /// When each badge was first unlocked. Key = badge ID, value = unlock time.
  final Map<String, DateTime> badgeUnlockedAt;

  bool hasBadge(String badgeId) => unlockedBadgeIds.contains(badgeId);

  /// Avatar border tier based on total badges unlocked:
  /// 0–4 → Bronze, 5–11 → Silver, 12–19 → Gold, 20+ → Diamond
  GamificationTier get playerTier {
    final count = unlockedBadgeIds.length;
    if (count >= 20) return GamificationTier.diamond;
    if (count >= 15) return GamificationTier.gold;
    if (count >= 10) return GamificationTier.silver;
    return GamificationTier.bronze;
  }

  static GamificationProfile empty(DateTime createdAt) => GamificationProfile(
        unlockedBadgeIds: [],
        updateCount: 0,
        paidOffDebts: 0,
        matureCount: 0,
        createdAt: createdAt,
        lastCheckedAt: createdAt,
      );

  factory GamificationProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GamificationProfile(
      unlockedBadgeIds:
          (d['unlockedBadgeIds'] as List<dynamic>?)?.cast<String>() ?? [],
      updateCount: (d['updateCount'] as num?)?.toInt() ?? 0,
      paidOffDebts: (d['paidOffDebts'] as num?)?.toInt() ?? 0,
      matureCount: (d['matureCount'] as num?)?.toInt() ?? 0,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastCheckedAt: d['lastCheckedAt'] != null
          ? (d['lastCheckedAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastUpdateCountedAt: d['lastUpdateCountedAt'] != null
          ? (d['lastUpdateCountedAt'] as Timestamp).toDate()
          : null,
      badgeUnlockedAt: (d['badgeUnlockedAt'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as Timestamp).toDate()),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toFirestore() => {
        'unlockedBadgeIds': unlockedBadgeIds,
        'updateCount': updateCount,
        'paidOffDebts': paidOffDebts,
        'matureCount': matureCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastCheckedAt': Timestamp.fromDate(lastCheckedAt),
        if (lastUpdateCountedAt != null)
          'lastUpdateCountedAt': Timestamp.fromDate(lastUpdateCountedAt!),
        'badgeUnlockedAt':
            badgeUnlockedAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      };

  GamificationProfile copyWith({
    List<String>? unlockedBadgeIds,
    int? updateCount,
    int? paidOffDebts,
    int? matureCount,
    DateTime? lastCheckedAt,
    DateTime? lastUpdateCountedAt,
    Map<String, DateTime>? badgeUnlockedAt,
  }) =>
      GamificationProfile(
        unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
        updateCount: updateCount ?? this.updateCount,
        paidOffDebts: paidOffDebts ?? this.paidOffDebts,
        matureCount: matureCount ?? this.matureCount,
        createdAt: createdAt,
        lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
        lastUpdateCountedAt: lastUpdateCountedAt ?? this.lastUpdateCountedAt,
        badgeUnlockedAt: badgeUnlockedAt ?? this.badgeUnlockedAt,
      );
}
