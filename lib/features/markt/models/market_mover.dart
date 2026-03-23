class MarketMover {
  const MarketMover({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
    required this.change,
    required this.currency,
    required this.exchange,
    required this.quoteType,
  });

  final String symbol;
  final String name;
  final double price;
  final double changePct;
  final double change;
  final String currency;
  final String exchange;
  final String quoteType; // 'EQUITY' or 'ETF'

  factory MarketMover.fromJson(Map<String, dynamic> j) => MarketMover(
        symbol: j['symbol'] as String? ?? '',
        name: j['name'] as String? ?? '',
        price: (j['price'] as num? ?? 0).toDouble(),
        changePct: (j['changePct'] as num? ?? 0).toDouble(),
        change: (j['change'] as num? ?? 0).toDouble(),
        currency: j['currency'] as String? ?? 'USD',
        exchange: j['exchange'] as String? ?? '',
        quoteType: j['quoteType'] as String? ?? 'EQUITY',
      );
}

class MarketIndex {
  const MarketIndex({
    required this.symbol,
    required this.name,
    required this.value,
    required this.changePct,
    required this.change,
  });

  final String symbol;
  final String name;
  final double value;
  final double changePct;
  final double change;

  factory MarketIndex.fromJson(Map<String, dynamic> j) => MarketIndex(
        symbol: j['symbol'] as String? ?? '',
        name: j['name'] as String? ?? '',
        value: (j['value'] as num? ?? 0).toDouble(),
        changePct: (j['changePct'] as num? ?? 0).toDouble(),
        change: (j['change'] as num? ?? 0).toDouble(),
      );
}

class MarketMoversResult {
  const MarketMoversResult({
    required this.indices,
    required this.stocks,
    required this.etfs,
    required this.trending,
    required this.actives,
    required this.updatedAt,
  });

  final List<MarketIndex> indices;
  final List<MarketMover> stocks;
  final List<MarketMover> etfs;
  final List<MarketMover> trending;
  final List<MarketMover> actives;
  final DateTime updatedAt;

  factory MarketMoversResult.fromJson(Map<String, dynamic> j) =>
      MarketMoversResult(
        indices: (j['indices'] as List<dynamic>? ?? [])
            .map((e) => MarketIndex.fromJson(e as Map<String, dynamic>))
            .toList(),
        stocks: (j['stocks'] as List<dynamic>? ?? [])
            .map((e) => MarketMover.fromJson(e as Map<String, dynamic>))
            .toList(),
        etfs: (j['etfs'] as List<dynamic>? ?? [])
            .map((e) => MarketMover.fromJson(e as Map<String, dynamic>))
            .toList(),
        trending: (j['trending'] as List<dynamic>? ?? [])
            .map((e) => MarketMover.fromJson(e as Map<String, dynamic>))
            .toList(),
        actives: (j['actives'] as List<dynamic>? ?? [])
            .map((e) => MarketMover.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String)
            : DateTime.now(),
      );
}
