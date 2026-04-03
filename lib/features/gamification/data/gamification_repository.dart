import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../models/gamification_models.dart';

/// All Firestore reads/writes for gamification.
///
/// Structure:
///   users/{uid}/gamification/profile  — GamificationProfile doc
class GamificationRepository {
  GamificationRepository(String userId)
      : _gamificationCol = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection(AppConstants.colGamification);

  final CollectionReference _gamificationCol;

  DocumentReference get _profileDoc =>
      _gamificationCol.doc(AppConstants.docGamificationProfile);

  // ── Profile ──────────────────────────────────────────────────────────────

  Stream<GamificationProfile?> watchProfile() => _profileDoc
      .snapshots()
      .map((s) => s.exists ? GamificationProfile.fromFirestore(s) : null);

  Future<GamificationProfile?> fetchProfile() async {
    final doc = await _profileDoc.get();
    if (!doc.exists) return null;
    return GamificationProfile.fromFirestore(doc);
  }

  /// Creates the profile document if it doesn't exist yet.
  Future<GamificationProfile> ensureProfile() async {
    final existing = await fetchProfile();
    if (existing != null) return existing;

    final fresh = GamificationProfile.empty(DateTime.now());
    await _profileDoc.set(fresh.toFirestore());
    return fresh;
  }

  Future<void> saveProfile(GamificationProfile profile) =>
      _profileDoc.set(profile.toFirestore());

  /// Atomically records newly unlocked badges.
  Future<void> awardBadges({required List<String> newBadgeIds}) {
    final now = Timestamp.fromDate(DateTime.now());
    return _profileDoc.update({
      'lastCheckedAt': now,
      if (newBadgeIds.isNotEmpty)
        'unlockedBadgeIds': FieldValue.arrayUnion(newBadgeIds),
      for (final id in newBadgeIds) 'badgeUnlockedAt.$id': now,
    });
  }

  Future<void> incrementUpdateCount() =>
      _profileDoc.update({'updateCount': FieldValue.increment(1)});

  Future<void> incrementPaidOffDebts() =>
      _profileDoc.update({'paidOffDebts': FieldValue.increment(1)});

  Future<void> incrementMatureCount() =>
      _profileDoc.update({'matureCount': FieldValue.increment(1)});

  /// Deletes the profile document (full reset).
  Future<void> resetAll() => _profileDoc.delete();
}
