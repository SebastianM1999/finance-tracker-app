import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../models/chip_alert.dart';
import '../models/chip_scan_result.dart';
import '../providers/chip_radar_providers.dart';
import '../widgets/stock_detail_sheet.dart';

class ChipRadarScreen extends ConsumerStatefulWidget {
  const ChipRadarScreen({super.key});

  @override
  ConsumerState<ChipRadarScreen> createState() => _ChipRadarScreenState();
}

class _ChipRadarScreenState extends ConsumerState<ChipRadarScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _thresholdExpanded = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chip Radar'),
        leading: const SizedBox.shrink(),
        leadingWidth: 52,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Watchlist'),
            Tab(text: 'Alarme'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _WatchlistTab(
            thresholdExpanded: _thresholdExpanded,
            onThresholdToggle: () =>
                setState(() => _thresholdExpanded = !_thresholdExpanded),
          ),
          const _AlertHistoryTab(),
        ],
      ),
    );
  }
}

// ── Watchlist tab ─────────────────────────────────────────────────────────────

class _WatchlistTab extends ConsumerWidget {
  const _WatchlistTab({
    required this.thresholdExpanded,
    required this.onThresholdToggle,
  });

  final bool thresholdExpanded;
  final VoidCallback onThresholdToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chipScanResultsProvider);

    return async.when(
      loading: () => _shimmerList(context),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar_outlined, size: 48),
            const SizedBox(height: 12),
            Text('Fehler beim Laden', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$e', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      data: (results) {
        final surged = results.where((r) => r.hasSurge).toList();
        return CustomScrollView(
          slivers: [
            if (surged.isNotEmpty)
              SliverToBoxAdapter(child: _SurgeBanner(surged: surged)),
            SliverToBoxAdapter(
              child: _ThresholdTable(
                expanded: thresholdExpanded,
                onToggle: onThresholdToggle,
              ),
            ),
            if (results.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radar_outlined, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'Noch keine Scandaten',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Der tägliche Scan läuft werktags um 22:00 Uhr UTC.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ScanResultRow(result: results[i])
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: i * 30), duration: 250.ms)
                      .slideX(begin: 0.04, end: 0),
                  childCount: results.length,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _shimmerList(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, i) => const _ShimmerRow(),
    );
  }
}

// ── Surge banner ──────────────────────────────────────────────────────────────

class _SurgeBanner extends StatelessWidget {
  const _SurgeBanner({required this.surged});
  final List<ChipScanResult> surged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF7B5800).withOpacity(0.35)
            : const Color(0xFFFFF3CD),
        border: Border.all(color: AppColors.darkWarning.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.radar, color: AppColors.darkWarning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${surged.length} Aktie${surged.length > 1 ? 'n' : ''} über Schwellenwert',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.darkWarning),
            ),
          ),
          Wrap(
            spacing: 4,
            children: surged
                .take(4)
                .map((r) => _TickerChip(ticker: r.ticker))
                .toList(),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.1, end: 0);
  }
}

class _TickerChip extends StatelessWidget {
  const _TickerChip({required this.ticker});
  final String ticker;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.darkWarning.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ticker,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkWarning),
      ),
    );
  }
}

// ── Threshold reference table ─────────────────────────────────────────────────

class _ThresholdTable extends StatelessWidget {
  const _ThresholdTable({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  static const _rows = [
    ('1d',   '≥ 10%',        'Daily spike'),
    ('7d',   '≥ 20%',        'Weekly momentum'),
    ('7d_s', '≥ 35%',        'Strong weekly surge'),
    ('14d',  '≥ 40%',        '2-week surge'),
    ('21d',  '≥ 60%',        'Major 3-week move'),
    ('vol',  '≥ 2× 30d avg', 'Unusual volume'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.secondary),
                const SizedBox(width: 6),
                Text('Alarm-Schwellenwerte',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.secondary)),
                const Spacer(),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: 250.ms,
          curve: Curves.easeInOut,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Column(
                    children: _rows.map((r) {
                      final (icon, color) = _alertIcon(r.$1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(icon, size: 14, color: color),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 44,
                              child: Text(r.$1,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            SizedBox(
                              width: 72,
                              child: Text(r.$2,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: color)),
                            ),
                            Text(r.$3, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.3)),
      ],
    );
  }
}

// ── Scan result row ───────────────────────────────────────────────────────────

class _ScanResultRow extends StatelessWidget {
  const _ScanResultRow({required this.result});
  final ChipScanResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = result.firestoreName ?? companyName(result.ticker);

    return InkWell(
      onTap: () => showStockDetailSheet(context, result),
      onLongPress: () => _openInBrowser(result.ticker),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(result.ticker,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          if (result.waveLabel != null) ...[
                            const SizedBox(width: 6),
                            _WaveBadge(label: result.waveLabel!),
                          ],
                        ],
                      ),
                      Text(name,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${result.price.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (result.lastUpdated.isNotEmpty)
                      Text(result.lastUpdated,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _ChangeCell(label: '1d',  value: result.change1d,  window: '1d',  result: result, isDark: isDark),
                const SizedBox(width: 4),
                _ChangeCell(label: '7d',  value: result.change7d,  window: '7d',  result: result, isDark: isDark),
                const SizedBox(width: 4),
                _ChangeCell(label: '14d', value: result.change14d, window: '14d', result: result, isDark: isDark),
                const SizedBox(width: 4),
                _ChangeCell(label: '21d', value: result.change21d, window: '21d', result: result, isDark: isDark),
                const SizedBox(width: 4),
                _VolumeCell(value: result.volumeRatio, result: result, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeCell extends StatelessWidget {
  const _ChangeCell({
    required this.label,
    required this.value,
    required this.window,
    required this.result,
    required this.isDark,
  });

  final String label;
  final double value;
  final String window;
  final ChipScanResult result;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = result.cellColor(window, isDark: isDark);
    final sign = value >= 0 ? '+' : '';
    final isHighlighted = result.isAboveThreshold(window) || result.isApproaching(window);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: bg == Colors.transparent
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : bg.withOpacity(0.25),
          borderRadius: BorderRadius.circular(6),
          border: isHighlighted
              ? Border.all(color: bg.withOpacity(0.7), width: 1)
              : null,
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            Text(
              '$sign${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? bg : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeCell extends StatelessWidget {
  const _VolumeCell({required this.value, required this.result, required this.isDark});
  final double value;
  final ChipScanResult result;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = result.cellColor('vol', isDark: isDark);
    final isHighlighted =
        result.isAboveThreshold('vol') || result.isApproaching('vol');

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: bg == Colors.transparent
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : bg.withOpacity(0.25),
          borderRadius: BorderRadius.circular(6),
          border: isHighlighted
              ? Border.all(color: bg.withOpacity(0.7), width: 1)
              : null,
        ),
        child: Column(
          children: [
            Text('vol',
                style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            Text(
              '${value.toStringAsFixed(1)}×',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? bg : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wave badge ────────────────────────────────────────────────────────────────

class _WaveBadge extends StatelessWidget {
  const _WaveBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final (display, color) = waveLabelStyle(label);
    if (display.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        display,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 60, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              Container(width: 120, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const Spacer(),
              Container(width: 70, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (_) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 34,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.1));
  }
}

// ── Alert history tab ─────────────────────────────────────────────────────────

class _AlertHistoryTab extends ConsumerWidget {
  const _AlertHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chipAlertHistoryProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (alerts) {
        if (alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_none_outlined, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Noch keine Alarme', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text(
                  'Alarme erscheinen hier sobald ein Schwellenwert überschritten wird.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Group by ticker + calendar day so each ticker shows once per day
        final map = <String, List<ChipAlert>>{};
        for (final a in alerts) {
          final day =
              '${a.timestamp.year}-${a.timestamp.month.toString().padLeft(2, '0')}-${a.timestamp.day.toString().padLeft(2, '0')}';
          map.putIfAbsent('${a.ticker}_$day', () => []).add(a);
        }
        final groups = map.values.toList();

        return ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => _AlertGroupTile(group: groups[i])
              .animate()
              .fadeIn(delay: Duration(milliseconds: i * 25), duration: 200.ms),
        );
      },
    );
  }
}

class _AlertGroupTile extends StatelessWidget {
  const _AlertGroupTile({required this.group});
  final List<ChipAlert> group;

  ChipAlert _dominant() {
    const order = ['21d', '7d_s', '14d', '7d', '1d', 'vol'];
    for (final w in order) {
      final m = group.where((a) => a.window == w).firstOrNull;
      if (m != null) return m;
    }
    return group.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = group.first;
    final dom = _dominant();
    final (icon, color) = _alertIcon(dom.window);

    return InkWell(
      onTap: () => _openInBrowser(first.ticker),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(first.ticker,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: group.map((a) => _AlertBadge(alert: a)).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${first.price.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF66BB6A)),
                ),
                const SizedBox(height: 3),
                Text(
                  _shortDate(first.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertBadge extends StatelessWidget {
  const _AlertBadge({required this.alert});
  final ChipAlert alert;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _alertIcon(alert.window);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            alert.formattedValue,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

(IconData, Color) _alertIcon(String window) => switch (window) {
      '1d'   => (Icons.trending_up,           const Color(0xFF42A5F5)), // blue 400
      '7d'   => (Icons.local_fire_department, const Color(0xFF26C6DA)), // cyan 400
      '7d_s' => (Icons.local_fire_department, const Color(0xFFFFCA28)), // amber 400
      '14d'  => (Icons.warning_rounded,       const Color(0xFFFFA726)), // orange 400
      '21d'  => (Icons.crisis_alert,          const Color(0xFFEF5350)), // red 400
      'vol'  => (Icons.bar_chart,             const Color(0xFFAB47BC)), // purple 400
      _      => (Icons.notifications,         Colors.grey),
    };

// "09.05 22:54"  — no year, keeps the trailing column compact
String _shortDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}'
    ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';


Future<void> _openInBrowser(String ticker) async {
  final url = Uri.parse('https://finance.yahoo.com/quote/$ticker');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
