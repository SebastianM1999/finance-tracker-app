import 'package:cloud_firestore/cloud_firestore.dart';

class Schuld {
  const Schuld({
    required this.id,
    required this.type,
    required this.personOrInstitution,
    required this.amount,
    this.description,
    this.dueDate,
    required this.createdAt,
  });

  final String id;
  final String type; // 'I_OWE' | 'OWED_TO_ME'
  final String personOrInstitution;
  final double amount;
  final String? description;
  final DateTime? dueDate;
  final DateTime createdAt;

  bool get iOwe => type == 'I_OWE';

  factory Schuld.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Schuld(
      id: doc.id,
      type: d['type'] as String,
      personOrInstitution: d['personOrInstitution'] as String,
      amount: (d['amount'] as num).toDouble(),
      description: d['description'] as String?,
      dueDate: d['dueDate'] != null ? (d['dueDate'] as Timestamp).toDate() : null,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'personOrInstitution': personOrInstitution,
        'amount': amount,
        'description': description,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
