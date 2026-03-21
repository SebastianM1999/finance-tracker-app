import 'package:cloud_firestore/cloud_firestore.dart';

class GiroAccount {
  const GiroAccount({
    required this.id,
    required this.bankName,
    required this.accountLabel,
    required this.balance,
    this.currency = 'EUR',
    this.notes,
    required this.updatedAt,
    required this.createdAt,
    this.colorValue = 0xFF5B8DEF, // default blue
  });

  final String id;
  final String bankName;
  final String accountLabel;
  final double balance;
  final String currency;
  final String? notes;
  final DateTime updatedAt;
  final DateTime createdAt;
  final int colorValue;

  factory GiroAccount.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GiroAccount(
      id: doc.id,
      bankName: d['bankName'] as String,
      accountLabel: d['accountLabel'] as String,
      balance: (d['balance'] as num).toDouble(),
      currency: d['currency'] as String? ?? 'EUR',
      notes: d['notes'] as String?,
      updatedAt: (d['updatedAt'] as Timestamp).toDate(),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      colorValue: d['colorValue'] as int? ?? 0xFF5B8DEF,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'bankName': bankName,
        'accountLabel': accountLabel,
        'balance': balance,
        'currency': currency,
        'notes': notes,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdAt': Timestamp.fromDate(createdAt),
        'colorValue': colorValue,
      };

  GiroAccount copyWith({
    String? bankName,
    String? accountLabel,
    double? balance,
    String? currency,
    String? notes,
    int? colorValue,
  }) =>
      GiroAccount(
        id: id,
        bankName: bankName ?? this.bankName,
        accountLabel: accountLabel ?? this.accountLabel,
        balance: balance ?? this.balance,
        currency: currency ?? this.currency,
        notes: notes ?? this.notes,
        colorValue: colorValue ?? this.colorValue,
        updatedAt: DateTime.now(),
        createdAt: createdAt,
      );
}
