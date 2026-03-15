import 'package:cloud_firestore/cloud_firestore.dart';

class PhysicalAsset {
  const PhysicalAsset({
    required this.id,
    required this.assetType,
    required this.description,
    required this.quantity,
    this.weightPerUnit,
    required this.buyPrice,
    required this.currentValue,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String assetType; // 'Gold' | 'Silver' | 'Other'
  final String description;
  final double quantity;
  final double? weightPerUnit;
  final double buyPrice;
  final double currentValue;
  final String? notes;
  final DateTime createdAt;

  double get pnlAbsolute => currentValue - buyPrice;
  double get pnlPercent => buyPrice == 0 ? 0 : (pnlAbsolute / buyPrice) * 100;

  factory PhysicalAsset.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PhysicalAsset(
      id: doc.id,
      assetType: d['assetType'] as String,
      description: d['description'] as String,
      quantity: (d['quantity'] as num).toDouble(),
      weightPerUnit: d['weightPerUnit'] != null
          ? (d['weightPerUnit'] as num).toDouble()
          : null,
      buyPrice: (d['buyPrice'] as num).toDouble(),
      currentValue: (d['currentValue'] as num).toDouble(),
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'assetType': assetType,
        'description': description,
        'quantity': quantity,
        'weightPerUnit': weightPerUnit,
        'buyPrice': buyPrice,
        'currentValue': currentValue,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
