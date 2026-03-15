import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../models/physical_asset.dart';

class AssetsRepository {
  AssetsRepository(this._userId)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection(AppConstants.colPhysical);

  final String _userId; // ignore: unused_field
  final CollectionReference _col;

  Stream<List<PhysicalAsset>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PhysicalAsset.fromFirestore).toList());

  Future<DocumentReference> add(PhysicalAsset a) => _col.add(a.toFirestore());
  Future<void> update(PhysicalAsset a) => _col.doc(a.id).update(a.toFirestore());
  Future<void> delete(String id) => _col.doc(id).delete();
}
