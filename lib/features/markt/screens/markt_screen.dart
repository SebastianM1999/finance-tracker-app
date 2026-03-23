import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/market_mover.dart';
import '../providers/market_providers.dart';

class MarktScreen extends ConsumerStatefulWidget {
  const MarktScreen({super.key, this.scrollController});
  final ScrollController? scrollController;

  @override
  ConsumerState<MarktScreen> createState() => _MarktScreenState();
}

class _MarktScreenState extends ConsumerState<MarktScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moversAsync = ref.watch(marketMoversProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined,
                      color: Colors.white54, size: 20),
                  onPressed: () => ref.invalidate(marketMoversProvider),
                  tooltip: 'Aktualisieren',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Markt',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Live Marktdaten',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                moversAsync.when(
                  data: (d) => Text(
                    _formatTime(d.updatedAt),
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Indices bar ────────────────────────────────────────────────────
          moversAsync.when(
            data: (d) => d.indices.isEmpty
                ? const SizedBox.shrink()
                : _IndicesBar(indices: d.indices),
            loading: () => const _IndicesBarSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // ── Tabs ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.darkPrimary,
              unselectedLabelColor: Colors.white38,
              indicatorColor: AppColors.darkPrimary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.white10,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Aktien'),
                Tab(text: 'ETFs'),
                Tab(text: 'Trending'),
                Tab(text: 'Aktiv'),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: moversAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Marktdaten werden geladen…',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        color: Colors.white24, size: 40),
                    const SizedBox(height: 12),
                    const Text('Konnte nicht laden',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(e.toString(),
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(marketMoversProvider),
                      child: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              ),
              data: (d) => TabBarView(
                controller: _tabs,
                children: [
                  _MoversList(
                    items: d.stocks,
                    emptyMessage: 'Keine Aktien-Daten verfügbar',
                    subtitle: 'Wöchentliche Performance · sortiert nach Rendite',
                  ),
                  _MoversList(
                    items: d.etfs,
                    emptyMessage: 'Keine ETF-Daten verfügbar',
                    subtitle: 'Wöchentliche Performance · sortiert nach Rendite',
                  ),
                  _MoversList(
                    items: d.trending,
                    emptyMessage: 'Keine Trending-Daten verfügbar',
                    subtitle: 'Meistgesuchte Assets heute',
                  ),
                  _MoversList(
                    items: d.actives,
                    emptyMessage: 'Keine Daten verfügbar',
                    subtitle: 'Höchstes Handelsvolumen heute',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Gerade aktualisiert';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    return 'vor ${diff.inHours} Std.';
  }
}

// ── Indices bar ───────────────────────────────────────────────────────────────

class _IndicesBar extends StatelessWidget {
  const _IndicesBar({required this.indices});
  final List<MarketIndex> indices;

  String _fmtValue(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 1000) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: indices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final idx = indices[i];
          final isPos = idx.changePct >= 0;
          final changeColor =
              isPos ? AppColors.darkPositive : AppColors.darkSecondary;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  idx.name,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmtValue(idx.value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${isPos ? '+' : ''}${idx.changePct.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IndicesBarSkeleton extends StatelessWidget {
  const _IndicesBarSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, __) => Container(
          width: 90,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ── Movers list ───────────────────────────────────────────────────────────────

class _MoversList extends StatelessWidget {
  const _MoversList({
    required this.items,
    required this.emptyMessage,
    required this.subtitle,
  });

  final List<MarketMover> items;
  final String emptyMessage;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_outlined,
                color: Colors.white12, size: 40),
            const SizedBox(height: 10),
            Text(emptyMessage,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text(subtitle,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11)),
        ),
        ...items.map((m) => _MoverTile(mover: m)),
      ],
    );
  }
}

// ── Single mover tile ─────────────────────────────────────────────────────────

class _MoverTile extends StatelessWidget {
  const _MoverTile({required this.mover});
  final MarketMover mover;

  @override
  Widget build(BuildContext context) {
    final isPos = mover.changePct >= 0;
    final changeColor =
        isPos ? AppColors.darkPositive : AppColors.darkSecondary;
    final typeColor = mover.quoteType == 'ETF'
        ? const Color(0xFF3F8ACB)
        : AppColors.darkPositive;
    final symbol = mover.symbol.split('.').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          // Symbol badge — type-colored
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: typeColor.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    symbol.length > 4 ? symbol.substring(0, 4) : symbol,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + exchange
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mover.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  mover.symbol,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Price + change chip
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${mover.currency == 'USD' ? '\$' : mover.currency == 'EUR' ? '€' : '${mover.currency} '}${mover.price.toStringAsFixed(mover.price < 10 ? 3 : 2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPos ? Icons.arrow_upward : Icons.arrow_downward,
                      color: changeColor,
                      size: 10,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${isPos ? '+' : ''}${mover.changePct.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
