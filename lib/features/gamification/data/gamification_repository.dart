import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../models/gamification_models.dart';

/// All Firestore reads/writes for gamification.
///
/// Structure:
///   users/{uid}/gamification/profile         — GamificationProfile doc
///   users/{uid}/gamification/xpEvents/{id}   — XPEvent sub-collection
class GamificationRepository {
  GamificationRepository(String userId)
      : _gamificationCol = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection(AppConstants.colGamification);

  final CollectionReference _gamificationCol;

  DocumentReference get _profileDoc =>
      _gamificationCol.doc(AppConstants.docGamificationProfile);

  CollectionReference get _xpEventsCol =>
      _profileDoc.collection(AppConstants.colXpEvents);

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

  /// Atomically increments totalXP and updates level + lastCheckedAt.
  Future<void> incrementXP({
    required int xp,
    required int newLevel,
    required List<String> newBadgeIds,
    required List<String> newChallengeIds,
  }) {
    final now = Timestamp.fromDate(DateTime.now());
    return _profileDoc.update({
      'totalXP': FieldValue.increment(xp),
      'level': newLevel,
      'lastCheckedAt': now,
      if (newBadgeIds.isNotEmpty)
        'unlockedBadgeIds': FieldValue.arrayUnion(newBadgeIds),
      if (newChallengeIds.isNotEmpty)
        'completedChallengeIds': FieldValue.arrayUnion(newChallengeIds),
      // Write unlock timestamp for each new badge using dot-notation
      // so existing entries in the map are never overwritten.
      for (final id in newBadgeIds) 'badgeUnlockedAt.$id': now,
    });
  }

  Future<void> incrementUpdateCount() =>
      _profileDoc.update({'updateCount': FieldValue.increment(1)});

  Future<void> incrementPaidOffDebts() =>
      _profileDoc.update({'paidOffDebts': FieldValue.increment(1)});

  Future<void> incrementMatureCount() =>
      _profileDoc.update({'matureCount': FieldValue.increment(1)});

  // ── XP Events (deduplication) ────────────────────────────────────────────

  /// Returns true if the event ID has already been awarded.
  Future<bool> hasXPEvent(String eventId) async {
    final doc = await _xpEventsCol.doc(eventId).get();
    return doc.exists;
  }

  /// Returns all awarded event IDs (for batch checking).
  Future<Set<String>> fetchAwardedEventIds() async {
    final snap = await _xpEventsCol.get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// Records a new XP event. Silently no-ops if the event ID already exists.
  Future<void> recordXPEvent(XPEvent event) =>
      _xpEventsCol.doc(event.id).set(event.toFirestore());

  /// Batch-records multiple events in a single Firestore write.
  Future<void> recordXPEvents(List<XPEvent> events) async {
    if (events.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final e in events) {
      batch.set(_xpEventsCol.doc(e.id), e.toFirestore());
    }
    await batch.commit();
  }

  /// Deletes all XP events and the profile document (full reset).
  Future<void> resetAll() async {
    final events = await _xpEventsCol.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in events.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_profileDoc);
    await batch.commit();
  }
}
