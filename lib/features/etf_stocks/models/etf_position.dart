import 'package:cloud_firestore/cloud_firestore.dart';

class EtfPosition {
  const EtfPosition({
    required this.id,
    this.broker = '',
    required this.name,
    this.ticker,
    required this.shares,
    required this.buyPrice,
    required this.currentPrice,
    this.currency = 'EUR',
    required this.assetType,
    this.lastPriceUpdate,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String broker; // kept for backward-compat with existing Firestore docs
  final String name;
  final String? ticker;
  final double shares;
  final double buyPrice;
  final double currentPrice;
  final String currency;
  final String assetType; // 'ETF' | 'Stock'
  final DateTime? lastPriceUpdate;
  final String? notes;
  final DateTime createdAt;

  double get currentValue => shares * currentPrice;
  double get buyValue => shares * buyPrice;
  double get pnlAbsolute => currentValue - buyValue;
  double get pnlPercent => buyValue == 0 ? 0 : (pnlAbsolute / buyValue) * 100;

  factory EtfPosition.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EtfPosition(
      id: doc.id,
      broker: (d['broker'] as String?) ?? '',
      name: d['name'] as String,
      ticker: d['ticker'] as String?,
      shares: (d['shares'] as num).toDouble(),
      buyPrice: (d['buyPrice'] as num).toDouble(),
      currentPrice: (d['currentPrice'] as num).toDouble(),
      currency: d['currency'] as String? ?? 'EUR',
      assetType: d['assetType'] as String,
      lastPriceUpdate: d['lastPriceUpdate'] != null
          ? (d['lastPriceUpdate'] as Timestamp).toDate()
          : null,
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'broker': broker,
        'name': name,
        'ticker': ticker,
        'shares': shares,
        'buyPrice': buyPrice,
        'currentPrice': currentPrice,
        'currency': currency,
        'assetType': assetType,
        'lastPriceUpdate':
            lastPriceUpdate != null ? Timestamp.fromDate(lastPriceUpdate!) : null,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
