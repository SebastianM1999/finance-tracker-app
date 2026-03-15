import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../models/crypto_position.dart';

class CryptoRepository {
  CryptoRepository(this._userId)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection(AppConstants.colCrypto);

  final String _userId; // ignore: unused_field
  final CollectionReference _col;

  Stream<List<CryptoPosition>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(CryptoPosition.fromFirestore).toList());

  Future<DocumentReference> add(CryptoPosition p) => _col.add(p.toFirestore());
  Future<void> update(CryptoPosition p) => _col.doc(p.id).update(p.toFirestore());
  Future<void> delete(String id) => _col.doc(id).delete();
}
