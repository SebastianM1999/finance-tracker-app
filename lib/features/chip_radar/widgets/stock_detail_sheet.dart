import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/chip_scan_result.dart';
import '../models/stock_detail.dart' show StockDetail, MacdData;
import '../services/chip_detail_service.dart';

void showStockDetailSheet(BuildContext context, ChipScanResult result) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StockDetailSheet(result: result),
  );
}

class _StockDetailSheet extends StatefulWidget {
  const _StockDetailSheet({required this.result});
  final ChipScanResult result;

  @override
  State<_StockDetailSheet> createState() => _StockDetailSheetState();
}

class _StockDetailSheetState extends State<_StockDetailSheet> {
  StockDetail? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ChipDetailService.fetch(widget.result.ticker).then((d) {
      if (mounted) setState(() { _detail = d; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.ticker,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (r.firestoreName != null)
                          Text(r.firestoreName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5))),
                      ],
                    ),
                  ),
                  Text(
                    '\$${r.price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF66BB6A)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_detail == null)
                    Center(
                      child: Text('Keine Daten verfügbar',
                          style: theme.textTheme.bodySmall),
                    )
                  else ...[
                    _Week52Bar(result: r, detail: _detail!)
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 20),
                    _RSIGauge(rsi: _detail!.rsi14)
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 300.ms)
                        .slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 20),
                    _MacdCard(macd: _detail!.macd)
                        .animate()
                        .fadeIn(delay: 160.ms, duration: 300.ms)
                        .slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 20),
                    _AnalystCard(detail: _detail!, currentPrice: r.price)
                        .animate()
                        .fadeIn(delay: 240.ms, duration: 300.ms)
                        .slideY(begin: 0.05, end: 0),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 52-week range bar ─────────────────────────────────────────────────────────

class _Week52Bar extends StatelessWidget {
  const _Week52Bar({required this.result, required this.detail});
  final ChipScanResult result;
  final StockDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final low = detail.week52Low;
    final high = detail.week52High;

    return _Card(
      title: '52-Wochen Range',
      child: low == null || high == null
          ? Text('—', style: theme.textTheme.bodySmall)
          : Column(
              children: [
                _RangeBar(low: low, high: high, current: result.price),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Label('Tief', '\$${low.toStringAsFixed(2)}',
                        const Color(0xFFEF5350)),
                    _Label(
                      'Aktuell',
                      '\$${result.price.toStringAsFixed(2)}',
                      const Color(0xFF66BB6A),
                      center: true,
                    ),
                    _Label('Hoch', '\$${high.toStringAsFixed(2)}',
                        const Color(0xFF42A5F5),
                        alignRight: true),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar(
      {required this.low, required this.high, required this.current});
  final double low, high, current;

  @override
  Widget build(BuildContext context) {
    final range = high - low;
    final position = range > 0 ? ((current - low) / range).clamp(0.0, 1.0) : 0.5;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return SizedBox(
        height: 28,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Track
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(colors: [
                  Color(0xFFEF5350),
                  Color(0xFFFFCA28),
                  Color(0xFF42A5F5),
                ]),
              ),
            ),
            // Thumb
            Positioned(
              left: (position * w - 9).clamp(0.0, w - 18),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── RSI gauge ─────────────────────────────────────────────────────────────────

class _RSIGauge extends StatelessWidget {
  const _RSIGauge({required this.rsi});
  final double? rsi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String label;
    Color color;
    if (rsi == null) {
      label = '—';
      color = Colors.grey;
    } else if (rsi! < 30) {
      label = 'Überverkauft';
      color = const Color(0xFF42A5F5);
    } else if (rsi! > 70) {
      label = 'Überkauft';
      color = const Color(0xFFEF5350);
    } else {
      label = 'Neutral';
      color = const Color(0xFF66BB6A);
    }

    return _Card(
      title: 'RSI (14)',
      child: rsi == null
          ? Text('—', style: theme.textTheme.bodySmall)
          : Column(
              children: [
                Row(
                  children: [
                    Text(
                      rsi!.toStringAsFixed(1),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800, color: color),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _RSIBar(rsi: rsi!),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0  Überverkauft <30',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                    Text('>70 Überkauft  100',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RSIBar extends StatelessWidget {
  const _RSIBar({required this.rsi});
  final double rsi;

  @override
  Widget build(BuildContext context) {
    final position = (rsi / 100).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return SizedBox(
        height: 28,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(colors: [
                  Color(0xFF42A5F5),
                  Color(0xFF66BB6A),
                  Color(0xFFFFCA28),
                  Color(0xFFEF5350),
                ]),
              ),
            ),
            // Oversold zone marker
            Positioned(
              left: w * 0.3 - 0.5,
              child: Container(width: 1, height: 12,
                  color: Colors.white.withOpacity(0.3)),
            ),
            // Overbought zone marker
            Positioned(
              left: w * 0.7 - 0.5,
              child: Container(width: 1, height: 12,
                  color: Colors.white.withOpacity(0.3)),
            ),
            Positioned(
              left: (position * w - 9).clamp(0.0, w - 18),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: rsi < 30
                          ? const Color(0xFF42A5F5)
                          : rsi > 70
                              ? const Color(0xFFEF5350)
                              : const Color(0xFF66BB6A),
                      width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── MACD card ─────────────────────────────────────────────────────────────────

class _MacdCard extends StatelessWidget {
  const _MacdCard({required this.macd});
  final MacdData? macd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = macd;

    if (m == null) {
      return _Card(
        title: 'MACD (12, 26, 9)',
        child: Text('—', style: theme.textTheme.bodySmall),
      );
    }

    final bullish = m.isBullish;
    final strengthening = m.isStrengthening;
    final signalColor =
        bullish ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);

    String interpretation;
    if (bullish && strengthening) {
      interpretation = 'Momentum aufbauend — bullisch';
    } else if (bullish && !strengthening) {
      interpretation = 'Bullisch aber nachlassend';
    } else if (!bullish && !strengthening) {
      interpretation = 'Momentum abbauend — bärisch';
    } else {
      interpretation = 'Bärisch aber nachlassend';
    }

    return _Card(
      title: 'MACD (12, 26, 9)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signal pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: signalColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: signalColor.withOpacity(0.4)),
            ),
            child: Text(
              interpretation,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: signalColor),
            ),
          ),
          const SizedBox(height: 12),
          // Three values in a row
          Row(
            children: [
              _MacdStat('MACD', m.macd, signalColor),
              const SizedBox(width: 20),
              _MacdStat('Signal', m.signal,
                  theme.colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 20),
              _MacdStat(
                'Histogramm',
                m.histogram,
                m.histogram >= 0
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFEF5350),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mini histogram bar chart (last 10 days)
          if (m.histogramSeries.isNotEmpty)
            _HistogramMiniChart(series: m.histogramSeries),
        ],
      ),
    );
  }
}

class _MacdStat extends StatelessWidget {
  const _MacdStat(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sign = value >= 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text('$sign${value.toStringAsFixed(3)}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _HistogramMiniChart extends StatelessWidget {
  const _HistogramMiniChart({required this.series});
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final maxAbs = series.map((v) => v.abs()).fold(0.0, max);
    if (maxAbs == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Histogramm (10 Tage)',
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: CustomPaint(
            painter: _HistPainter(series: series, maxAbs: maxAbs),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _HistPainter extends CustomPainter {
  _HistPainter({required this.series, required this.maxAbs});
  final List<double> series;
  final double maxAbs;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final barW = size.width / series.length;
    final gap = barW * 0.18;

    // Centre line
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = Colors.grey.withOpacity(0.25)
        ..strokeWidth = 0.8,
    );

    for (int i = 0; i < series.length; i++) {
      final val = series[i];
      final frac = val.abs() / maxAbs;
      final barH = (frac * (midY - 2)).clamp(1.5, midY - 2);
      final isLast = i == series.length - 1;
      final color = val >= 0
          ? (isLast ? const Color(0xFF43A047) : const Color(0xFF81C784))
          : (isLast ? const Color(0xFFE53935) : const Color(0xFFEF9A9A));

      final left = i * barW + gap;
      final right = (i + 1) * barW - gap;
      final top = val >= 0 ? midY - barH : midY;
      final bottom = val >= 0 ? midY : midY + barH;

      canvas.drawRRect(
        RRect.fromLTRBR(left, top, right, bottom, const Radius.circular(2)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_HistPainter old) =>
      old.series != series || old.maxAbs != maxAbs;
}

// ── Analyst card ──────────────────────────────────────────────────────────────

class _AnalystCard extends StatelessWidget {
  const _AnalystCard({required this.detail, required this.currentPrice});
  final StockDetail detail;
  final double currentPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = detail.recommendationKey?.toLowerCase() ?? '';
    final (recLabel, recColor) = switch (key) {
      'strong_buy' => ('Strong Buy', const Color(0xFF43A047)),
      'buy'        => ('Buy',         const Color(0xFF66BB6A)),
      'hold'       => ('Hold',        const Color(0xFFFFCA28)),
      'underperform' || 'sell' => ('Sell', const Color(0xFFEF5350)),
      _ => ('—', Colors.grey),
    };

    final upside = detail.targetMeanPrice != null
        ? ((detail.targetMeanPrice! - currentPrice) / currentPrice * 100)
        : null;

    return _Card(
      title: 'Analysten (${detail.numberOfAnalysts ?? '?'} Meinungen)',
      child: Row(
        children: [
          // Recommendation pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: recColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: recColor.withOpacity(0.5)),
            ),
            child: Text(recLabel,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: recColor)),
          ),
          const SizedBox(width: 20),
          if (detail.targetMeanPrice != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kursziel (Ø)',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    '\$${detail.targetMeanPrice!.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (upside != null)
                    Text(
                      '${upside >= 0 ? '+' : ''}${upside.toStringAsFixed(1)}% vs. heute',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: upside >= 0
                              ? const Color(0xFF66BB6A)
                              : const Color(0xFFEF5350)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label, this.value, this.color,
      {this.center = false, this.alignRight = false});
  final String label, value;
  final Color color;
  final bool center, alignRight;

  @override
  Widget build(BuildContext context) {
    final align = alignRight
        ? CrossAxisAlignment.end
        : center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
