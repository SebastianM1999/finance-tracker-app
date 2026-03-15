import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../models/giro_account.dart';

class GiroRepository {
  GiroRepository(this._userId)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection(AppConstants.colGiro);

  final String _userId; // ignore: unused_field
  final CollectionReference _col;

  Stream<List<GiroAccount>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(GiroAccount.fromFirestore).toList());

  Future<void> add(GiroAccount account) =>
      _col.doc(account.id.isEmpty ? null : account.id).set(account.toFirestore());

  Future<void> update(GiroAccount account) =>
      _col.doc(account.id).update(account.toFirestore());

  Future<void> delete(String id) => _col.doc(id).delete();
}
