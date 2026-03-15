import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../models/festgeld.dart';

class FestgeldRepository {
  FestgeldRepository(this._userId)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection(AppConstants.colFestgeld);

  final String _userId; // ignore: unused_field
  final CollectionReference _col;

  Stream<List<Festgeld>> watchAll() => _col
      .orderBy('endDate')
      .snapshots()
      .map((s) => s.docs.map(Festgeld.fromFirestore).toList());

  Future<DocumentReference> add(Festgeld f) => _col.add(f.toFirestore());

  Future<void> update(Festgeld f) => _col.doc(f.id).update(f.toFirestore());

  Future<void> delete(String id) => _col.doc(id).delete();
}
