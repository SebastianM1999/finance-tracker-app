import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../models/watchlist_item.dart';

class WatchlistRepository {
  WatchlistRepository(String userId)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection(AppConstants.colWatchlist);

  final CollectionReference _col;

  Stream<List<WatchlistItem>> watchAll() => _col
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(WatchlistItem.fromFirestore).toList());

  Future<void> add(WatchlistItem item) => _col.add(item.toFirestore());
  Future<void> update(WatchlistItem item) =>
      _col.doc(item.id).update(item.toFirestore());
  Future<void> delete(String id) => _col.doc(id).delete();
}
