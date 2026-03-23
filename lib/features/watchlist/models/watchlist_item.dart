import 'package:cloud_firestore/cloud_firestore.dart';

class WatchlistItem {
  const WatchlistItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    this.targetPrice,
    this.lastKnownPrice,
    required this.addedAt,
    this.lastPriceUpdate,
    this.notifiedAt,
  });

  final String id;
  final String symbol; // e.g. "AAPL", "BTC", "VWCE.DE"
  final String name;
  final String type; // "stock" | "etf" | "crypto"
  final double? targetPrice; // alert threshold in EUR, null = no alert
  final double? lastKnownPrice; // cached last known EUR price
  final DateTime addedAt;
  final DateTime? lastPriceUpdate;
  final DateTime? notifiedAt; // set by CF when alert fires; null = not yet notified

  WatchlistItem copyWith({
    double? lastKnownPrice,
    DateTime? lastPriceUpdate,
    double? targetPrice,
    bool clearTarget = false,
    bool clearNotified = false,
    DateTime? notifiedAt,
  }) =>
      WatchlistItem(
        id: id,
        symbol: symbol,
        name: name,
        type: type,
        targetPrice: clearTarget ? null : (targetPrice ?? this.targetPrice),
        lastKnownPrice: lastKnownPrice ?? this.lastKnownPrice,
        addedAt: addedAt,
        lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
        notifiedAt: clearNotified ? null : (notifiedAt ?? this.notifiedAt),
      );

  factory WatchlistItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WatchlistItem(
      id: doc.id,
      symbol: d['symbol'] as String? ?? '',
      name: d['name'] as String? ?? '',
      type: d['type'] as String? ?? 'stock',
      targetPrice: (d['targetPrice'] as num?)?.toDouble(),
      lastKnownPrice: (d['lastKnownPrice'] as num?)?.toDouble(),
      addedAt: (d['addedAt'] as Timestamp).toDate(),
      lastPriceUpdate: d['lastPriceUpdate'] != null
          ? (d['lastPriceUpdate'] as Timestamp).toDate()
          : null,
      notifiedAt: d['notifiedAt'] != null
          ? (d['notifiedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'symbol': symbol,
        'name': name,
        'type': type,
        'targetPrice': targetPrice,
        'lastKnownPrice': lastKnownPrice,
        'addedAt': Timestamp.fromDate(addedAt),
        'lastPriceUpdate':
            lastPriceUpdate != null ? Timestamp.fromDate(lastPriceUpdate!) : null,
        'notifiedAt':
            notifiedAt != null ? Timestamp.fromDate(notifiedAt!) : null,
      };
}
