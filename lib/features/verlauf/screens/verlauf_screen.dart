import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/models/net_worth_snapshot.dart';
import '../../home/providers/home_providers.dart';

// ── Range state ───────────────────────────────────────────────────────────────

String _fmtY(double v) {
  if (v.abs() >= 1000000) return '€${(v / 1000000).toStringAsFixed(1)}M';
  if (v.abs() >= 1000) return '€${(v / 1000).toStringAsFixed(0)}k';
  return '€${v.toStringAsFixed(0)}';
}

final _verlaufRangeProvider = StateProvider<int>((ref) => 30);

// days value → human label
String _rangeLabel(int days) => switch (days) {
      30 => 'letzten 30 Tagen',
      180 => 'letzten 6 Monaten',
      365 => 'letzten 12 Monaten',
      _ => 'gesamten Zeitraum',
    };

// ── Screen ────────────────────────────────────────────────────────────────────

class VerlaufScreen extends ConsumerWidget {
  const VerlaufScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(_verlaufRangeProvider);
    final historyAsync = ref.watch(netWorthRangeProvider(days));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verlauf'),
        centerTitle: false,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (history) => _VerlaufBody(history: history, days: days),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _VerlaufBody extends ConsumerWidget {
  const _VerlaufBody({required this.history, required this.days});

  final List<NetWorthSnapshot> history;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Range selector
        _RangeSelector(selected: days),
        const SizedBox(height: 20),

        // Change badge
        if (history.length >= 2) _ChangeBadge(history: history, days: days),
        if (history.length >= 2) const SizedBox(height: 16),

        // Chart
        _HistoryChart(history: history),
        const SizedBox(height: 28),

        // Snapshots list
        if (history.isNotEmpty) ...[
          Text('Verlaufseinträge',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...history.reversed.map((s) => _SnapshotTile(snapshot: s)),
        ],

        if (history.isEmpty)
          _EmptyState(days: days),
      ],
    );
  }
}

// ── Range Selector ────────────────────────────────────────────────────────────

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector({required this.selected});
  final int selected;

  static const _options = [
    (30, '1M'),
    (180, '6M'),
    (365, '1J'),
    (0, 'Alles'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: _options.map(((int, String) opt) {
          final (days, label) = opt;
          final isSelected = selected == days;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(_verlaufRangeProvider.notifier).state = days,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.darkPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Change Badge ──────────────────────────────────────────────────────────────

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.history, required this.days});
  final List<NetWorthSnapshot> history;
  final int days;

  @override
  Widget build(BuildContext context) {
    final first = history.first.totalNetWorth;
    final last = history.last.totalNetWorth;
    final absolute = last - first;
    final percent = first == 0 ? 0.0 : (absolute / first) * 100;
    final isPos = absolute >= 0;

    final label = _rangeLabel(days);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: (isPos ? AppColors.darkPositive : AppColors.darkSecondary)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isPos ? AppColors.darkPositive : AppColors.darkSecondary)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: AppColors.darkTextSecondary, fontSize: 13),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatPnl(absolute),
                style: TextStyle(
                  color: isPos ? AppColors.darkPositive : AppColors.darkSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                CurrencyFormatter.formatPercent(percent),
                style: TextStyle(
                  color: isPos ? AppColors.darkPositive : AppColors.darkSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _HistoryChart extends StatefulWidget {
  const _HistoryChart({required this.history});
  final List<NetWorthSnapshot> history;

  @override
  State<_HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<_HistoryChart> {
  static final _axisDate = DateFormat('dd.MM.');

  @override
  Widget build(BuildContext context) {
    final history = widget.history;

    if (history.length < 2) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Center(
          child: Text(
            'Noch nicht genug Daten',
            style: TextStyle(
                color: AppColors.darkTextSecondary, fontSize: 13),
          ),
        ),
      );
    }

    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.totalNetWorth))
        .toList();

    final minY = history.map((s) => s.totalNetWorth).reduce((a, b) => a < b ? a : b);
    final maxY = history.map((s) => s.totalNetWorth).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;

    // Pick ~4 evenly spaced x-axis labels
    final step = (history.length / 4).ceil().clamp(1, history.length);

    return GestureDetector(
      child: Container(
        height: 260,
        padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: LineChart(
          LineChartData(
            minY: minY - padding,
            maxY: maxY + padding,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: padding > 0 ? (maxY - minY + 2 * padding) / 4 : 1,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.darkBorder,
                strokeWidth: 0.8,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _fmtY(value),
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: step.toDouble(),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= history.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _axisDate.format(history[i].recordedAt),
                        style: const TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchCallback: (event, response) {
                if (event is FlTapUpEvent &&
                    response?.lineBarSpots != null) {
                  final idx = response!.lineBarSpots!.first.spotIndex;
                  _showDetail(context, history[idx]);
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          CurrencyFormatter.formatCompact(s.y),
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.darkPrimary,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.darkPrimary.withValues(alpha: 0.3),
                      AppColors.darkPrimary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, NetWorthSnapshot snapshot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SnapshotDetailSheet(snapshot: snapshot),
    );
  }
}

// ── Snapshot Tile (list item) ─────────────────────────────────────────────────

class _SnapshotTile extends StatelessWidget {
  const _SnapshotTile({required this.snapshot});
  final NetWorthSnapshot snapshot;

  static final _dateFmt = DateFormat('dd. MMMM yyyy', 'de_DE');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          _dateFmt.format(snapshot.recordedAt),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          CurrencyFormatter.format(snapshot.totalNetWorth),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SnapshotDetailSheet(snapshot: snapshot),
        ),
      ),
    );
  }
}

// ── Snapshot Detail Sheet ─────────────────────────────────────────────────────

class _SnapshotDetailSheet extends StatelessWidget {
  const _SnapshotDetailSheet({required this.snapshot});
  final NetWorthSnapshot snapshot;

  static final _dateFmt = DateFormat('dd. MMMM yyyy', 'de_DE');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group positions by category
    final grouped = <String, List<SnapshotPosition>>{};
    for (final p in snapshot.positions) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    // Category breakdown rows
    final breakdownRows = [
      (
        'giro',
        'Giro Konten',
        snapshot.giro,
        Icons.account_balance_outlined,
        AppColors.gradientGiro,
      ),
      (
        'festgeld',
        'Festgeld',
        snapshot.festgeld,
        Icons.lock_clock_outlined,
        AppColors.gradientFestgeld,
      ),
      (
        'etf',
        'ETF & Aktien',
        snapshot.etfStocks,
        Icons.trending_up_outlined,
        AppColors.gradientEtf,
      ),
      (
        'crypto',
        'Krypto',
        snapshot.crypto,
        Icons.currency_bitcoin_outlined,
        AppColors.gradientCrypto,
      ),
      (
        'physical',
        'Sachwerte',
        snapshot.physical,
        Icons.inventory_2_outlined,
        AppColors.gradientPhysical,
      ),
      (
        'schulden',
        'Schulden',
        snapshot.schulden,
        Icons.balance_outlined,
        AppColors.gradientSchulden,
      ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dateFmt.format(snapshot.recordedAt),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        CurrencyFormatter.format(snapshot.totalNetWorth),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.darkPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // Category breakdown
                  Text('Aufteilung',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.darkTextSecondary)),
                  const SizedBox(height: 10),
                  ...breakdownRows.map(
                    (row) {
                      final (cat, label, value, icon, gradient) = row;
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: gradient),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon,
                                  color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(label,
                                  style: theme.textTheme.bodyMedium),
                            ),
                            Text(
                              CurrencyFormatter.format(value),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: value < 0
                                    ? AppColors.darkSecondary
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Individual positions
                  if (snapshot.positions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Positionen (${snapshot.positions.length})',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.darkTextSecondary),
                    ),
                    const SizedBox(height: 10),
                    ...snapshot.positions.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 10, top: 2),
                              decoration: BoxDecoration(
                                color: AppColors.darkPrimary
                                    .withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                p.name,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(p.value),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: p.value < 0
                                    ? AppColors.darkSecondary
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final label = _rangeLabel(days);

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.gradientEtf,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.show_chart_outlined,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Kein Verlauf in den $label',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Öffne die App regelmäßig und ändere\nPositionen, um den Verlauf aufzubauen.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
