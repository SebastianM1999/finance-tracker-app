import 'package:cloud_firestore/cloud_firestore.dart';

class ChipAlert {
  const ChipAlert({
    required this.ticker,
    this.name,
    required this.label,
    required this.window,
    required this.value,
    required this.price,
    required this.timestamp,
  });

  final String ticker;
  final String? name;
  final String label;
  final String window;
  final double value;
  final double price;
  final DateTime timestamp;

  factory ChipAlert.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChipAlert(
      ticker:    d['ticker']    as String? ?? '',
      name:      d['name']      as String?,
      label:     d['label']     as String? ?? '',
      window:    d['window']    as String? ?? '',
      value:     (d['value']    as num?)?.toDouble() ?? 0,
      price:     (d['price']    as num?)?.toDouble() ?? 0,
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get formattedValue {
    if (window == 'vol') return '${value.toStringAsFixed(1)}× Volumen';
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}%';
  }
}
