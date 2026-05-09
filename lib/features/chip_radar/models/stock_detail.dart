class MacdData {
  const MacdData({
    required this.macd,
    required this.signal,
    required this.histogram,
    required this.histogramSeries,
  });
  final double macd;
  final double signal;
  final double histogram;
  final List<double> histogramSeries; // last 10 daily values, oldest→newest

  factory MacdData.fromJson(Map<String, dynamic> j) => MacdData(
        macd:      (j['macd']      as num).toDouble(),
        signal:    (j['signal']    as num).toDouble(),
        histogram: (j['histogram'] as num).toDouble(),
        histogramSeries: (j['histogramSeries'] as List<dynamic>? ?? [])
            .map((v) => (v as num).toDouble())
            .toList(),
      );

  bool get isBullish => macd > signal;
  bool get isStrengthening => histogram > 0;

  bool get isMomentumBuilding {
    if (histogramSeries.length < 2) return false;
    final last = histogramSeries.last;
    final prev = histogramSeries[histogramSeries.length - 2];
    return last > prev && last > 0;
  }
}

class StockDetail {
  const StockDetail({
    required this.ticker,
    this.week52High,
    this.week52Low,
    this.targetMeanPrice,
    this.numberOfAnalysts,
    this.recommendationKey,
    this.recommendationMean,
    this.rsi14,
    this.macd,
  });

  final String ticker;
  final double? week52High;
  final double? week52Low;
  final double? targetMeanPrice;
  final int? numberOfAnalysts;
  final String? recommendationKey;
  final double? recommendationMean;
  final double? rsi14;
  final MacdData? macd;

  factory StockDetail.fromJson(Map<String, dynamic> j) => StockDetail(
        ticker:             j['ticker'] as String,
        week52High:         (j['week52High']         as num?)?.toDouble(),
        week52Low:          (j['week52Low']          as num?)?.toDouble(),
        targetMeanPrice:    (j['targetMeanPrice']    as num?)?.toDouble(),
        numberOfAnalysts:   (j['numberOfAnalysts']   as num?)?.toInt(),
        recommendationKey:  j['recommendationKey']   as String?,
        recommendationMean: (j['recommendationMean'] as num?)?.toDouble(),
        rsi14:              (j['rsi14']              as num?)?.toDouble(),
        macd: j['macd'] != null
            ? MacdData.fromJson(j['macd'] as Map<String, dynamic>)
            : null,
      );
}
