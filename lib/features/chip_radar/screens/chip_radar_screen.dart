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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: 'Filter-Info',
            onPressed: () => _showFilterInfo(context),
          ),
        ],
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
    final activeFilters = ref.watch(chipRadarFilterProvider);

    return async.when(
      loading: () => _shimmerList(),
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
        // Quality filter — hide incomplete or zero-priced rows
        final qualityFiltered = results
            .where((r) =>
                r.price > 0 &&
                !(r.change14d == 0.0 && r.change21d == 0.0))
            .toList();

        // Wave filter — apply user selection; empty set = show all
        final displayed = activeFilters.isEmpty
            ? qualityFiltered
            : qualityFiltered
                .where((r) =>
                    r.waveLabel != null &&
                    activeFilters.contains(r.waveLabel))
                .toList();

        return CustomScrollView(
          slivers: [
            if (qualityFiltered.isNotEmpty)
              SliverToBoxAdapter(child: _SummaryBanner(items: qualityFiltered)),
            const SliverToBoxAdapter(child: _WaveFilterRow()),
            SliverToBoxAdapter(
              child: _ThresholdTable(
                expanded: thresholdExpanded,
                onToggle: onThresholdToggle,
              ),
            ),
            if (displayed.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radar_outlined, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        activeFilters.isEmpty
                            ? 'Noch keine Scandaten'
                            : 'Keine Aktien mit dieser Auswahl',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeFilters.isEmpty
                            ? 'Der tägliche Scan läuft werktags um 23:00 Uhr.'
                            : 'Filter zurücksetzen um alle Aktien zu sehen.',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ScanResultRow(result: displayed[i])
                      .animate()
                      .fadeIn(
                          delay: Duration(milliseconds: i * 30),
                          duration: 250.ms)
                      .slideX(begin: 0.04, end: 0),
                  childCount: displayed.length,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _shimmerList() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, i) => const _ShimmerRow(),
    );
  }
}

// ── Summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.items});
  final List<ChipScanResult> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final withScore = items.where((r) => r.score != null).toList()
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

    String suffix;
    if (withScore.isNotEmpty) {
      final top = withScore.take(3).map((r) => '${r.ticker} ${r.score}').join(' · ');
      suffix = '  |  Top: $top';
    } else {
      final top = items.take(3).map((r) => r.ticker).join(' · ');
      suffix = '  |  $top';
    }

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
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkWarning,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(text: '${items.length} Aktien heute'),
                  TextSpan(
                    text: suffix,
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.1, end: 0);
  }
}

// ── Threshold reference table ─────────────────────────────────────────────────

class _ThresholdTable extends StatelessWidget {
  const _ThresholdTable({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  static const _rows = [
    ('1d',   '≥ 10% + 20d-Hoch',   'Tages-Spike'),
    ('7d',   '≥ 20% + Vol ≥1.5×',  'Wöchentl. Momentum'),
    ('7d_s', '≥ 35% + 55d-Hoch',   'Starker Wochenanstieg'),
    ('14d',  '≥ 40% + über SMA50', '2-Wochen-Anstieg'),
    ('21d',  '≥ 60% + 55d-Hoch',   'Großer 3-Wochen-Move'),
    ('vol',  '≥ 2.5× 20d-Median',  'Ungewöhnl. Volumen'),
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    children: _rows.map((r) {
                      final (icon, color) = _alertIcon(r.$1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 16, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(r.$1,
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: color)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(r.$3,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(r.$2,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontSize: 11,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.55))),
                                ],
                              ),
                            ),
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
    final name = result.firestoreName ?? companyName(result.ticker);

    return InkWell(
      onTap: () => showStockDetailSheet(context, result),
      onLongPress: () => _openInBrowser(result.ticker),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line 1: ticker · wave badge · score badge | price
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  result.ticker,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                if (result.waveLabel != null) _WaveBadge(label: result.waveLabel!),
                if (result.score != null) ...[
                  const SizedBox(width: 4),
                  _ScoreBadge(score: result.score!),
                ],
                const Spacer(),
                Text(
                  '\$${result.price.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Line 2: company name | last updated
            Row(
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
                const Spacer(),
                if (result.lastUpdated.isNotEmpty)
                  Text(
                    result.lastUpdated,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.35)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Line 3: metric chips (neutral bg, green border only on threshold hit)
            Row(
              children: [
                _MetricChip(label: '1d',  value: result.change1d,  window: '1d',  result: result),
                const SizedBox(width: 4),
                _MetricChip(label: '7d',  value: result.change7d,  window: '7d',  result: result),
                const SizedBox(width: 4),
                _MetricChip(label: '14d', value: result.change14d, window: '14d', result: result),
                const SizedBox(width: 4),
                _MetricChip(label: '21d', value: result.change21d, window: '21d', result: result),
                const SizedBox(width: 4),
                _MetricChip(label: 'vol', value: result.volumeRatio, window: 'vol', result: result),
              ],
            ),
            // Line 4: confirmatory tags
            _TagRow(result: result),
          ],
        ),
      ),
    );
  }
}

// ── Score badge ───────────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color text;
    if (score >= 80) {
      bg   = const Color(0xFFEAF3DE);
      text = const Color(0xFF3B6D11);
    } else if (score >= 60) {
      bg   = const Color(0xFFFAEEDA);
      text = const Color(0xFF854F0B);
    } else {
      bg   = Theme.of(context).colorScheme.surfaceContainerHighest;
      text = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$score',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }
}

// ── Tag row ───────────────────────────────────────────────────────────────────
// Tags are confirmatory signals — kept small and visually quiet (outline only,
// no fill) so they don't compete with the primary metric chips.

class _TagRow extends StatelessWidget {
  const _TagRow({required this.result});
  final ChipScanResult result;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[];

    if (result.newHigh252 == true) {
      tags.add('52w Hoch');
    } else if (result.newHigh55 == true) {
      tags.add('55d Hoch');
    } else if (result.newHigh20 == true) {
      tags.add('20d Hoch');
    }

    final sma20 = result.sma20;
    final sma50 = result.sma50;
    if (sma20 != null && sma50 != null &&
        result.price > sma20 && sma20 > sma50) {
      tags.add('SMA20>50');
    }

    if (result.closeLocation != null && result.closeLocation! >= 0.75) {
      tags.add('Nahe Tageshoch');
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Wrap(
        spacing: 4,
        runSpacing: 3,
        children: tags.map((t) => _TagChip(text: t)).toList(),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        ),
      ),
    );
  }
}

// ── Metric chip ───────────────────────────────────────────────────────────────
// All chips share a neutral surface background.
// Only chips that have crossed their alert threshold get a green border + bold
// green text. No colored fill on any chip.

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.window,
    required this.result,
  });

  final String label;
  final double value;
  final String window;
  final ChipScanResult result;

  @override
  Widget build(BuildContext context) {
    final isHit = result.isAboveThreshold(window);
    final formatted = window == 'vol'
        ? '${value.toStringAsFixed(1)}×'
        : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.45),
          borderRadius: BorderRadius.circular(6),
          border: isHit
              ? Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.55),
                  width: 0.9)
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4)),
            ),
            Text(
              formatted,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isHit ? FontWeight.w800 : FontWeight.w600,
                color: isHit
                    ? const Color(0xFF4CAF50)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wave filter row ───────────────────────────────────────────────────────────
//
// Horizontally scrollable row of chips, one per wave label plus an "Alle"
// reset chip. Active chips are filled; inactive chips are outlined.
// State is persisted via ChipRadarFilterNotifier.

class _WaveFilterRow extends ConsumerWidget {
  const _WaveFilterRow();

  static const _waveLabels = [
    'early', 'accumulating', 'running', 'watching', 'extended',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilters = ref.watch(chipRadarFilterProvider);
    final notifier = ref.read(chipRadarFilterProvider.notifier);
    final theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _WaveChip(
            label: 'Alle',
            color: theme.colorScheme.primary,
            active: activeFilters.isEmpty,
            onTap: notifier.clearAll,
          ),
          const SizedBox(width: 6),
          ..._waveLabels.map((wl) {
            final (display, color) = waveLabelStyle(wl);
            if (display.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _WaveChip(
                label: display,
                color: color,
                active: activeFilters.contains(wl),
                onTap: () => notifier.toggle(wl),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _WaveChip extends StatelessWidget {
  const _WaveChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : color.withOpacity(0.35),
            width: active ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? color : color.withOpacity(0.6),
          ),
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

// ── Alert history tab (performance tracker) ───────────────────────────────────

// One entry per ticker: most recent alert + current scan price.
class _AlertEntry {
  _AlertEntry({
    required this.alert,
    required this.currentPrice,
    this.waveLabel,
  });
  final ChipAlert alert;
  final double? currentPrice;
  final String? waveLabel;

  double? get perf {
    if (alert.price <= 0 || currentPrice == null) return null;
    return (currentPrice! - alert.price) / alert.price * 100;
  }
}

class _AlertHistoryTab extends ConsumerWidget {
  const _AlertHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertAsync   = ref.watch(chipAlertHistoryProvider);
    final scanMapAsync = ref.watch(chipScanResultsMapProvider);

    return alertAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (alerts) {
        if (alerts.isEmpty) return _emptyState(context);

        final scanMap = scanMapAsync.valueOrNull ?? {};

        // Deduplicate: one entry per ticker, keep the most recent alert.
        final Map<String, ChipAlert> latest = {};
        for (final a in alerts) {
          final existing = latest[a.ticker];
          if (existing == null || a.timestamp.isAfter(existing.timestamp)) {
            latest[a.ticker] = a;
          }
        }

        // Build entries, sort by perf% descending; no current price → bottom.
        final entries = latest.values
            .map((a) => _AlertEntry(
                  alert: a,
                  currentPrice: scanMap[a.ticker]?.price,
                  waveLabel: scanMap[a.ticker]?.waveLabel,
                ))
            .toList()
          ..sort((a, b) {
            final pa = a.perf;
            final pb = b.perf;
            if (pa == null && pb == null) return 0;
            if (pa == null) return 1;
            if (pb == null) return -1;
            return pb.compareTo(pa);
          });

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _PerformanceBanner(
                entries: entries,
                allAlerts: alerts,
                scanMap: scanMap,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Column(
                  children: [
                    _PerformanceTile(entry: entries[i])
                        .animate()
                        .fadeIn(
                            delay: Duration(milliseconds: i * 25),
                            duration: 220.ms)
                        .slideX(begin: 0.03, end: 0),
                    const Divider(height: 1),
                  ],
                ),
                childCount: entries.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📡', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Noch keine Alarme',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Der tägliche Scan läuft nach US-Börsenschluss (23:00 Uhr).\nAlarme erscheinen hier sobald Schwellenwerte überschritten werden.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Performance summary banner ────────────────────────────────────────────────

class _PerformanceBanner extends StatelessWidget {
  const _PerformanceBanner({
    required this.entries,
    required this.allAlerts,
    required this.scanMap,
  });
  final List<_AlertEntry> entries;
  final List<ChipAlert> allAlerts;
  final Map<String, ChipScanResult> scanMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cutoff = DateTime.now().subtract(const Duration(days: 7));

    // Count and average over all raw alerts in the last 7 days.
    final recent = allAlerts.where((a) => a.timestamp.isAfter(cutoff)).toList();
    final perfs = recent
        .where((a) => a.price > 0 && scanMap[a.ticker]?.price != null)
        .map((a) => (scanMap[a.ticker]!.price - a.price) / a.price * 100)
        .toList();

    final avg = perfs.isEmpty
        ? null
        : perfs.reduce((a, b) => a + b) / perfs.length;

    final avgColor = avg == null
        ? theme.colorScheme.onSurface.withOpacity(0.7)
        : avg >= 0
            ? const Color(0xFF66BB6A)
            : const Color(0xFFEF5350);

    final avgStr = avg == null
        ? '—'
        : '${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('📊', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                    fontSize: 13, color: theme.colorScheme.onSurface),
                children: [
                  const TextSpan(
                    text: 'Letzte 7 Tage: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: '${recent.length} Alarme',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '  ·  Ø '),
                  TextSpan(
                    text: avgStr,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: avgColor),
                  ),
                  const TextSpan(text: ' seit Alarm'),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.1, end: 0);
  }
}

// ── Performance tile ──────────────────────────────────────────────────────────

class _PerformanceTile extends StatelessWidget {
  const _PerformanceTile({required this.entry});
  final _AlertEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alert = entry.alert;
    final perf = entry.perf;

    final perfColor = perf == null
        ? theme.colorScheme.onSurface.withOpacity(0.35)
        : perf >= 0
            ? const Color(0xFF66BB6A)
            : const Color(0xFFEF5350);

    final perfText = perf == null
        ? '—'
        : '${perf >= 0 ? '+' : ''}${perf.toStringAsFixed(1)}%';

    return InkWell(
      onTap: () => _openChartInBrowser(alert.ticker),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: ticker + wave badge + date + alert→current prices
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(alert.ticker,
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2)),
                      if (entry.waveLabel != null) ...[
                        const SizedBox(width: 6),
                        _WaveBadge(label: entry.waveLabel!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _alertDateLabel(alert.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.45)),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '\$${alert.price.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.45)),
                      ),
                      if (entry.currentPrice != null) ...[
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward,
                              size: 10,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.3)),
                        ),
                        Text(
                          '\$${entry.currentPrice!.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.65)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Right: % change — large and prominent
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  perfText,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: perfColor,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.open_in_new,
                  size: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.25),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter info sheet ─────────────────────────────────────────────────────────

void _showFilterInfo(BuildContext context) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 1,
        minChildSize: 1,
        maxChildSize: 1,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.radar, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Was wird angezeigt?',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FilterRow(
                icon: Icons.check_circle_outline,
                color: const Color(0xFF66BB6A),
                label: 'Preis ≥ \$15',
                detail: 'Penny Stocks unter \$15 werden ignoriert.',
              ),
              _FilterRow(
                icon: Icons.check_circle_outline,
                color: const Color(0xFF66BB6A),
                label: '20d Median-Dollarvolumen ≥ \$20 Mio.',
                detail: 'Illiquide Micro-Caps werden ausgeblendet.',
              ),
              _FilterRow(
                icon: Icons.check_circle_outline,
                color: const Color(0xFF66BB6A),
                label: 'Alle Zeitfenster positiv (7d, 14d, 21d)',
                detail: 'Dead-Cat-Bounces werden herausgefiltert.',
              ),
              _FilterRow(
                icon: Icons.check_circle_outline,
                color: const Color(0xFF66BB6A),
                label: 'Preis über SMA20 und SMA50',
                detail: 'Nur bestätigte Aufwärtstrends werden angezeigt.',
              ),
              _FilterRow(
                icon: Icons.check_circle_outline,
                color: const Color(0xFF66BB6A),
                label: 'Im oberen 60 % der 52-Wochen-Range',
                detail: 'Aktien nahe ihrem Jahreshoch bevorzugt.',
              ),
              const SizedBox(height: 20),
              Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.block_outlined, color: Color(0xFFEF5350), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Was wird ignoriert?',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FilterRow(
                icon: Icons.remove_circle_outline,
                color: const Color(0xFFEF5350),
                label: 'Preis < \$15',
                detail: 'Penny Stocks — zu anfällig für Manipulation.',
              ),
              _FilterRow(
                icon: Icons.remove_circle_outline,
                color: const Color(0xFFEF5350),
                label: 'Negative Rendite in irgendeinem Fenster',
                detail: 'Dead-Cat-Bounce-Muster werden vollständig ausgeschlossen.',
              ),
              _FilterRow(
                icon: Icons.remove_circle_outline,
                color: const Color(0xFFEF5350),
                label: 'Preis unter SMA20 oder SMA50',
                detail: 'Kein bestätigter Aufwärtstrend.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Der tägliche Scan prüft ~8.000 US-Aktien. Nach Phase-3-Filtern verbleiben typischerweise 30–80 hochqualitative Aktien.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
              const SizedBox(height: 16),
              // ── Section 3: Wave classification ─────────────────────────────
              Row(
                children: [
                  Icon(Icons.category_outlined,
                      color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Wie werden Aktien bewertet?',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _WaveInfoRow(
                color: const Color(0xFF66BB6A),
                badge: 'Early',
                title: 'Frühzeitiger Ausbruch',
                detail:
                    'Neue Hochs, RSI noch nicht überhitzt, frisches Momentum.',
              ),
              _WaveInfoRow(
                color: const Color(0xFF42A5F5),
                badge: 'Akkumulierung',
                title: 'Stille Stärke',
                detail:
                    '63-Tage-Trend solide, SMA-Struktur intakt, noch kein Spike.',
              ),
              _WaveInfoRow(
                color: const Color(0xFFFFCA28),
                badge: 'Running',
                title: 'Volles Momentum',
                detail:
                    'Alle Zeitfenster stark, institutionelles Volumen bestätigt.',
              ),
              _WaveInfoRow(
                color: Colors.grey,
                badge: 'Beobachten',
                title: 'Auf dem Radar',
                detail: 'Nähert sich Schwellenwerten, noch kein Alarm.',
              ),
              _WaveInfoRow(
                color: const Color(0xFFEF5350),
                badge: 'Extended',
                title: 'Überhitzt',
                detail:
                    'Move bereits weit fortgeschritten, spätes Einstiegssignal.',
              ),
              const SizedBox(height: 10),
              Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
              const SizedBox(height: 10),
              // ── Footer ─────────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Max. 50 Aktien werden täglich angezeigt — sortiert nach Gesamtscore.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.65)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wave info row (used in the ⓘ sheet, section 3) ───────────────────────────

class _WaveInfoRow extends StatelessWidget {
  const _WaveInfoRow({
    required this.color,
    required this.badge,
    required this.title,
    required this.detail,
  });
  final Color color;
  final String badge;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.45), width: 0.8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

(IconData, Color) _alertIcon(String window) => switch (window) {
      '1d'   => (Icons.trending_up,           const Color(0xFF42A5F5)),
      '7d'   => (Icons.local_fire_department, const Color(0xFF26C6DA)),
      '7d_s' => (Icons.local_fire_department, const Color(0xFFFFCA28)),
      '14d'  => (Icons.warning_rounded,       const Color(0xFFFFA726)),
      '21d'  => (Icons.crisis_alert,          const Color(0xFFEF5350)),
      'vol'  => (Icons.bar_chart,             const Color(0xFFAB47BC)),
      _      => (Icons.notifications,         Colors.grey),
    };

String _alertDateLabel(DateTime dt) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date  = DateTime(dt.year, dt.month, dt.day);
  final diff  = today.difference(date).inDays;
  const months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
  final dateStr = '${dt.day}. ${months[dt.month - 1]}';
  if (diff == 0) return 'Heute';
  if (diff == 1) return 'Gestern';
  return dateStr;
}

Future<void> _openInBrowser(String ticker) async {
  final url = Uri.parse('https://finance.yahoo.com/quote/$ticker');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

Future<void> _openChartInBrowser(String ticker) async {
  final url = Uri.parse('https://finance.yahoo.com/quote/$ticker/chart/');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
