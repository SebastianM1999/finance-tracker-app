import 'package:cloud_firestore/cloud_firestore.dart';

class SnapshotPosition {
  const SnapshotPosition({
    required this.category,
    required this.name,
    required this.value,
  });

  final String category; // 'giro' | 'festgeld' | 'etf' | 'crypto' | 'physical' | 'schulden'
  final String name;
  final double value;

  factory SnapshotPosition.fromMap(Map<String, dynamic> m) => SnapshotPosition(
        category: m['category'] as String? ?? '',
        name: m['name'] as String? ?? '',
        value: (m['value'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'category': category,
        'name': name,
        'value': value,
      };
}

class NetWorthSnapshot {
  const NetWorthSnapshot({
    required this.id,
    required this.totalNetWorth,
    required this.giro,
    required this.festgeld,
    required this.etfStocks,
    required this.crypto,
    required this.physical,
    required this.schulden,
    required this.recordedAt,
    this.positions = const [],
  });

  final String id;
  final double totalNetWorth;
  final double giro;
  final double festgeld;
  final double etfStocks;
  final double crypto;
  final double physical;
  final double schulden;
  final DateTime recordedAt;
  final List<SnapshotPosition> positions;

  factory NetWorthSnapshot.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final breakdown = d['breakdown'] as Map<String, dynamic>? ?? {};
    final posRaw = d['positions'] as List<dynamic>? ?? [];
    return NetWorthSnapshot(
      id: doc.id,
      totalNetWorth: (d['totalNetWorth'] as num).toDouble(),
      giro: (breakdown['giro'] as num? ?? 0).toDouble(),
      festgeld: (breakdown['festgeld'] as num? ?? 0).toDouble(),
      etfStocks: (breakdown['etf_stocks'] as num? ?? 0).toDouble(),
      crypto: (breakdown['crypto'] as num? ?? 0).toDouble(),
      physical: (breakdown['physical'] as num? ?? 0).toDouble(),
      schulden: (breakdown['schulden'] as num? ?? 0).toDouble(),
      recordedAt: (d['recordedAt'] as Timestamp).toDate(),
      positions: posRaw
          .map((e) => SnapshotPosition.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'totalNetWorth': totalNetWorth,
        'breakdown': {
          'giro': giro,
          'festgeld': festgeld,
          'etf_stocks': etfStocks,
          'crypto': crypto,
          'physical': physical,
          'schulden': schulden,
        },
        'positions': positions.map((p) => p.toMap()).toList(),
        'recordedAt': Timestamp.fromDate(recordedAt),
      };
}
