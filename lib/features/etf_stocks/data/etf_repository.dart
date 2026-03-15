import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../models/etf_position.dart';

class EtfRepository {
  EtfRepository(this._userId)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection(AppConstants.colEtfStocks);

  final String _userId; // ignore: unused_field
  final CollectionReference _col;

  Stream<List<EtfPosition>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(EtfPosition.fromFirestore).toList());

  Future<DocumentReference> add(EtfPosition p) => _col.add(p.toFirestore());
  Future<void> update(EtfPosition p) => _col.doc(p.id).update(p.toFirestore());
  Future<void> delete(String id) => _col.doc(id).delete();
}
