import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/providers/home_providers.dart';

class FestgeldDetailScreen extends ConsumerWidget {
  const FestgeldDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(festgeldStreamProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Festgeld & Zinserträge'),
        centerTitle: false,
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'Noch keine Festgeld-Einträge',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.45), fontSize: 14),
              ),
            );
          }

          final totalCapital =
              list.fold(0.0, (s, f) => s + f.amount);
          final totalProjected =
              list.fold(0.0, (s, f) => s + f.projectedPayout - f.amount);
          final weightedRate = totalCapital == 0
              ? 0.0
              : list.fold(0.0,
                      (s, f) => s + f.interestRate * f.amount) /
                  totalCapital;

          final sortedByMaturity = [...list]
            ..sort((a, b) => a.endDate.compareTo(b.endDate));
          final nextMaturity = sortedByMaturity.first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              _SummaryCard(
                totalCapital: totalCapital,
                weightedRate: weightedRate,
                totalProjected: totalProjected,
              ),
              const SizedBox(height: 20),
              _RateBarChart(festgeldList: list),
              const SizedBox(height: 20),
              _NextMaturityBadge(festgeld: nextMaturity),
              const SizedBox(height: 16),
              ...sortedByMaturity.map((f) => _FestgeldTile(
                    festgeld: f,
                    isNext: f.id == nextMaturity.id,
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCapital,
    required this.weightedRate,
    required this.totalProjected,
  });
  final double totalCapital, weightedRate, totalProjected;

  @override
  Widget build(BuildContext context) {
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
              label: 'Kapital',
              value: CurrencyFormatter.format(totalCapital),
            ),
          ),
          Container(
              width: 1,
              height: 36,
              color: outline.withValues(alpha: 0.2)),
          Expanded(
            child: _SummaryCell(
              label: 'Ø Zinssatz',
              value: '${weightedRate.toStringAsFixed(2)}%',
            ),
          ),
          Container(
              width: 1,
              height: 36,
              color: outline.withValues(alpha: 0.2)),
          Expanded(
            child: _SummaryCell(
              label: 'Zinserträge',
              value: '+${CurrencyFormatter.format(totalProjected)}',
              valueColor: AppColors.positive(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell(
      {required this.label, required this.value, this.valueColor});
  final String label, value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              color: valueColor ?? onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                color: onSurface.withValues(alpha: 0.45), fontSize: 11),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _RateBarChart extends StatelessWidget {
  const _RateBarChart({required this.festgeldList});
  final festgeldList;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    final list = (festgeldList as List);

    final barGroups = list.asMap().entries.map((entry) {
      final f = entry.value;
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: f.interestRate,
            color: AppColors.chartFestgeld,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        showingTooltipIndicators: [],
      );
    }).toList();

    final maxRate = list.fold<double>(0.0,
            (m, f) => (f.interestRate as double) > m ? (f.interestRate as double) : m) +
        0.5;

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
          Text('Zinssätze',
              style: TextStyle(
                  color: onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: maxRate,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: outline.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: onSurface.withValues(alpha: 0.4),
                            fontSize: 9),
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
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= list.length) {
                          return const SizedBox.shrink();
                        }
                        final bank = list[idx].bankName as String;
                        return Text(
                          bank.length > 6 ? bank.substring(0, 6) : bank,
                          style: TextStyle(
                              color: onSurface.withValues(alpha: 0.4),
                              fontSize: 9),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) {
                      final f = list[group.x];
                      return BarTooltipItem(
                        '${f.bankName}\n${f.interestRate.toStringAsFixed(2)}%',
                        TextStyle(
                            color: AppColors.chartFestgeld,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextMaturityBadge extends StatelessWidget {
  const _NextMaturityBadge({required this.festgeld});
  final festgeld;

  @override
  Widget build(BuildContext context) {
    final daysLeft = (festgeld.daysRemaining as int);
    final color = daysLeft <= 30
        ? AppColors.secondary(context)
        : daysLeft <= 90
            ? AppColors.warning(context)
            : AppColors.positive(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nächste Fälligkeit: ${festgeld.bankName} — ${daysLeft <= 0 ? 'fällig!' : 'in $daysLeft Tagen'}',
              style: TextStyle(
                  color: onSurface, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FestgeldTile extends StatelessWidget {
  const _FestgeldTile({required this.festgeld, required this.isNext});
  final festgeld;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    final interest = (festgeld.projectedPayout as double) -
        (festgeld.amount as double);
    final endDate = festgeld.endDate as DateTime;
    final daysLeft = festgeld.daysRemaining as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNext
              ? AppColors.chartFestgeld.withValues(alpha: 0.5)
              : outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  festgeld.bankName as String,
                  style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.chartFestgeld.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(festgeld.interestRate as double).toStringAsFixed(2)}%',
                  style: const TextStyle(
                      color: AppColors.chartFestgeld,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _InfoChip(
                icon: Icons.euro,
                label: CurrencyFormatter.format(festgeld.amount as double),
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.calendar_today,
                label: DateFormat('dd.MM.yyyy').format(endDate),
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.hourglass_bottom,
                label: daysLeft <= 0 ? 'Fällig!' : '$daysLeft T.',
                color: daysLeft <= 30
                    ? AppColors.secondary(context)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '+${CurrencyFormatter.format(interest)} projizierte Zinsen',
            style: TextStyle(
                color: AppColors.positive(context),
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final c = color ?? onSurface.withValues(alpha: 0.55);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(color: c, fontSize: 11)),
      ],
    );
  }
}
