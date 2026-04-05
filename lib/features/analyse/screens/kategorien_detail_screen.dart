import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/providers/home_providers.dart';

final _kategorienRangeProvider = StateProvider.autoDispose<int>((ref) => 30);
final _kategorienVisibleProvider =
    StateProvider.autoDispose<Set<int>>((ref) => {0, 1, 2, 3, 4});

class KategorienDetailScreen extends ConsumerWidget {
  const KategorienDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(_kategorienRangeProvider);
    ref.watch(netWorthRangeProvider(30));
    ref.watch(netWorthRangeProvider(90));
    ref.watch(netWorthRangeProvider(180));
    ref.watch(netWorthRangeProvider(365));
    final historyAsync = ref.watch(netWorthRangeProvider(days));
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategorie-Entwicklung'),
        centerTitle: false,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (history) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              _KategorienRangeSelector(selected: days),
              const SizedBox(height: 20),
              if (history.length < 2)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text(
                      'Noch zu wenige Verlaufsdaten für diesen Zeitraum.',
                      style: TextStyle(
                          color: onSurface.withValues(alpha: 0.5),
                          fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                _KategorienChart(history: history),
                const SizedBox(height: 20),
                _KategorienLegend(history: history),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _KategorienRangeSelector extends ConsumerWidget {
  const _KategorienRangeSelector({required this.selected});
  final int selected;

  static const _options = [
    (30, '1M'),
    (90, '3M'),
    (180, '6M'),
    (365, '1J'),
  ];

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
                ref.read(_kategorienRangeProvider.notifier).state = days,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

class _KategorienChart extends ConsumerWidget {
  const _KategorienChart({required this.history});
  final history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(_kategorienVisibleProvider);
    final outline = Theme.of(context).colorScheme.outline;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    const lineConfigs = [
      ('Giro', AppColors.chartGiro, 0),
      ('Festgeld', AppColors.chartFestgeld, 1),
      ('ETF', AppColors.chartEtf, 2),
      ('Krypto', AppColors.chartCrypto, 3),
      ('Sachwerte', AppColors.chartPhysical, 4),
    ];

    List<double> _valuesForIndex(int idx) => switch (idx) {
          0 => (history as List).map<double>((s) => s.giro as double).toList(),
          1 => (history as List).map<double>((s) => s.festgeld as double).toList(),
          2 => (history as List).map<double>((s) => s.etfStocks as double).toList(),
          3 => (history as List).map<double>((s) => s.crypto as double).toList(),
          _ => (history as List).map<double>((s) => s.physical as double).toList(),
        };

    final barData = lineConfigs
        .where((cfg) => visible.contains(cfg.$3))
        .map((cfg) {
          final values = _valuesForIndex(cfg.$3);
          return LineChartBarData(
            spots: values
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: cfg.$2,
            barWidth: 1.8,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          );
        })
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: lineConfigs.map((cfg) {
              final isOn = visible.contains(cfg.$3);
              return GestureDetector(
                onTap: () {
                  final notifier =
                      ref.read(_kategorienVisibleProvider.notifier);
                  final current = Set<int>.from(ref.read(_kategorienVisibleProvider));
                  if (isOn && current.length > 1) {
                    current.remove(cfg.$3);
                  } else {
                    current.add(cfg.$3);
                  }
                  notifier.state = current;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOn
                        ? cfg.$2.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOn
                          ? cfg.$2
                          : onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    cfg.$1,
                    style: TextStyle(
                      color: isOn ? cfg.$2 : onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight:
                          isOn ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: barData.isEmpty
                ? Center(
                    child: Text('Keine Kategorien ausgewählt',
                        style: TextStyle(
                            color: onSurface.withValues(alpha: 0.4),
                            fontSize: 12)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: outline.withValues(alpha: 0.15),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData:
                          const LineTouchData(enabled: false),
                      lineBarsData: barData,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KategorienLegend extends StatelessWidget {
  const _KategorienLegend({required this.history});
  final history;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    final last = (history as List).last;
    final entries = [
      ('Giro', AppColors.chartGiro, last.giro as double),
      ('Festgeld', AppColors.chartFestgeld, last.festgeld as double),
      ('ETF & Aktien', AppColors.chartEtf, last.etfStocks as double),
      ('Krypto', AppColors.chartCrypto, last.crypto as double),
      ('Sachwerte', AppColors.chartPhysical, last.physical as double),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: entries.where((e) => e.$3 > 0).map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                    width: 14,
                    height: 3,
                    color: e.$2,
                    margin: const EdgeInsets.only(right: 8)),
                Expanded(
                  child: Text(e.$1,
                      style: TextStyle(
                          color: onSurface.withValues(alpha: 0.65),
                          fontSize: 13)),
                ),
                Text(
                  CurrencyFormatter.format(e.$3),
                  style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
