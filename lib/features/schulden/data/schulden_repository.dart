import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../models/schuld.dart';

class SchuldenRepository {
  SchuldenRepository(this._userId)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection(AppConstants.colSchulden);

  final String _userId; // ignore: unused_field
  final CollectionReference _col;

  Stream<List<Schuld>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Schuld.fromFirestore).toList());

  Future<DocumentReference> add(Schuld s) => _col.add(s.toFirestore());
  Future<void> update(Schuld s) => _col.doc(s.id).update(s.toFirestore());
  Future<void> delete(String id) => _col.doc(id).delete();
}
