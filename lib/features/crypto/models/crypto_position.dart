import 'package:cloud_firestore/cloud_firestore.dart';

class CryptoPosition {
  const CryptoPosition({
    required this.id,
    required this.exchange,
    required this.coinName,
    required this.coinSymbol,
    required this.amount,
    required this.buyPrice,
    required this.currentPrice,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String exchange;
  final String coinName;
  final String coinSymbol;
  final double amount;
  final double buyPrice;
  final double currentPrice;
  final String? notes;
  final DateTime createdAt;

  double get currentValue => amount * currentPrice;
  double get buyValue => amount * buyPrice;
  double get pnlAbsolute => currentValue - buyValue;
  double get pnlPercent => buyValue == 0 ? 0 : (pnlAbsolute / buyValue) * 100;

  factory CryptoPosition.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CryptoPosition(
      id: doc.id,
      exchange: (d['exchange'] as String?) ?? '',
      coinName: d['coinName'] as String,
      coinSymbol: d['coinSymbol'] as String,
      amount: (d['amount'] as num).toDouble(),
      buyPrice: (d['buyPrice'] as num).toDouble(),
      currentPrice: (d['currentPrice'] as num).toDouble(),
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'exchange': exchange,
        'coinName': coinName,
        'coinSymbol': coinSymbol,
        'amount': amount,
        'buyPrice': buyPrice,
        'currentPrice': currentPrice,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
