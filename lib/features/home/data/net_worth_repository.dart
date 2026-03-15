import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../models/net_worth_snapshot.dart';

class NetWorthRepository {
  NetWorthRepository(this._userId)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection(AppConstants.colNetWorthHistory);

  final String _userId; // ignore: unused_field
  final CollectionReference _col;

  static final _dateId = DateFormat('yyyy-MM-dd');

  /// Streams snapshots for the last [days] days.
  /// Pass [days] = 0 to get all snapshots.
  Stream<List<NetWorthSnapshot>> watchRange(int days) {
    Query query;
    if (days == 0) {
      query = _col.orderBy('recordedAt');
    } else {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      query = _col
          .where('recordedAt', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('recordedAt');
    }
    return query
        .snapshots()
        .map((s) => s.docs.map(NetWorthSnapshot.fromFirestore).toList());
  }

  /// Upserts today's snapshot (one per calendar day, keyed by date).
  /// Calling this multiple times on the same day overwrites — always stores
  /// the latest values.
  Future<void> saveOrUpdate(NetWorthSnapshot snapshot) async {
    final docId = _dateId.format(snapshot.recordedAt);
    await _col.doc(docId).set(snapshot.toFirestore());
  }
}
