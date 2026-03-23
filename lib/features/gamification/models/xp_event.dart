import 'package:cloud_firestore/cloud_firestore.dart';

/// A single awarded XP event stored in Firestore.
/// The document ID is the [id] field and serves as the deduplication key.
class XPEvent {
  const XPEvent({
    required this.id,
    required this.xp,
    required this.reason,
    required this.awardedAt,
  });

  final String id;
  final int xp;
  final String reason;
  final DateTime awardedAt;

  factory XPEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return XPEvent(
      id: doc.id,
      xp: (d['xp'] as num).toInt(),
      reason: d['reason'] as String,
      awardedAt: (d['awardedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'xp': xp,
        'reason': reason,
        'awardedAt': Timestamp.fromDate(awardedAt),
      };
}
