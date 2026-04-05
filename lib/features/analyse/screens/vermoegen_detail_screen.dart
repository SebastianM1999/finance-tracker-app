import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/providers/home_providers.dart';

final _vermoegenRangeProvider = StateProvider.autoDispose<int>((ref) => 30);

class VermoegenDetailScreen extends ConsumerWidget {
  const VermoegenDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(_vermoegenRangeProvider);
    ref.watch(netWorthRangeProvider(30));
    ref.watch(netWorthRangeProvider(90));
    ref.watch(netWorthRangeProvider(365));
    final historyAsync = ref.watch(netWorthRangeProvider(days));
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vermögensentwicklung'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded,
                color: onSurface.withValues(alpha: 0.5)),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (history) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              _RangeSelector(selected: days),
              const SizedBox(height: 20),
              if (history.length >= 2) ...[
                _SummaryRow(history: history),
                const SizedBox(height: 20),
              ],
              _VermoegenChart(history: history),
              if (history.length < 2) ...[
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Noch zu wenige Verlaufsdaten für diesen Zeitraum.',
                    style: TextStyle(
                        color: onSurface.withValues(alpha: 0.5), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Was ist das Nettovermögen?',
            style: TextStyle(
                color: onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Das Nettovermögen ist die Summe aller Vermögenswerte (Giro, Festgeld, ETF, Krypto, Sachwerte) abzüglich deiner Schulden.\n\n'
          'Jedes Mal, wenn du dein Portfolio aktualisierst, wird ein Snapshot gespeichert. Diese Snapshots bilden den Verlauf.',
          style: TextStyle(
              color: onSurface.withValues(alpha: 0.7), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector({required this.selected});
  final int selected;

  static const _options = [(30, '30T'), (90, '90T'), (365, '1J')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: _options.map((opt) {
        final (days, label) = opt;
        final isSelected = days == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () =>
                ref.read(_vermoegenRangeProvider.notifier).state = days,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? primary
                      : onSurface.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? primary : onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.history});
  final history;

  @override
  Widget build(BuildContext context) {
    final first = history.first;
    final last = history.last;
    final delta = last.totalNetWorth - first.totalNetWorth;
    final pct = first.totalNetWorth == 0
        ? 0.0
        : (delta / first.totalNetWorth) * 100;
    final isPos = delta >= 0;
    final c = isPos ? AppColors.positive(context) : AppColors.secondary(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCell(
              label: 'Start',
              value: CurrencyFormatter.format(first.totalNetWorth),
              color: onSurface,
            ),
          ),
          Container(
              width: 1,
              height: 36,
              color: outline.withValues(alpha: 0.2)),
          Expanded(
            child: _SummaryCell(
              label: 'Aktuell',
              value: CurrencyFormatter.format(last.totalNetWorth),
              color: onSurface,
            ),
          ),
          Container(
              width: 1,
              height: 36,
              color: outline.withValues(alpha: 0.2)),
          Expanded(
            child: _SummaryCell(
              label: 'Änderung',
              value:
                  '${isPos ? '+' : ''}${pct.toStringAsFixed(1)}%',
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: onSurface.withValues(alpha: 0.45), fontSize: 11)),
      ],
    );
  }
}

class _VermoegenChart extends StatelessWidget {
  const _VermoegenChart({required this.history});
  final history;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (history.length < 2) {
      return const SizedBox.shrink();
    }

    final spots = history
        .asMap()
        .entries
        .map<FlSpot>(
            (e) => FlSpot(e.key.toDouble(), e.value.totalNetWorth))
        .toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final pad = range == 0 ? 1000.0 : range * 0.1;

    String _fmtY(double v) {
      if (v.abs() >= 1000000) return '€${(v / 1000000).toStringAsFixed(1)}M';
      if (v.abs() >= 1000) return '€${(v / 1000).toStringAsFixed(0)}k';
      return '€${v.toStringAsFixed(0)}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outline.withValues(alpha: 0.12)),
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: minY - pad,
            maxY: maxY + pad,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: outline.withValues(alpha: 0.15),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(
                    _fmtY(v),
                    style: TextStyle(
                        color: onSurface.withValues(alpha: 0.4), fontSize: 10),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval:
                      (spots.length / 4).ceilToDouble().clamp(1, double.infinity),
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= history.length) {
                      return const SizedBox.shrink();
                    }
                    final date = history[idx].recordedAt;
                    return Text(
                      DateFormat('dd.MM').format(date),
                      style: TextStyle(
                          color: onSurface.withValues(alpha: 0.4),
                          fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          CurrencyFormatter.format(s.y),
                          TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: primary,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
