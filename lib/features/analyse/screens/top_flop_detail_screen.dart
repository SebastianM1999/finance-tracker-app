import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../home/providers/home_providers.dart';

class TopFlopDetailScreen extends ConsumerWidget {
  const TopFlopDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etfList = ref.watch(etfStreamProvider).valueOrNull ?? [];
    final cryptoList = ref.watch(cryptoStreamProvider).valueOrNull ?? [];
    final assetsList = ref.watch(assetsStreamProvider).valueOrNull ?? [];
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final positions = <(String, double, Color)>[];
    for (final e in etfList) {
      if (e.buyPrice > 0) {
        positions.add((
          e.ticker ?? e.name,
          (e.currentPrice / e.buyPrice - 1) * 100,
          AppColors.chartEtf,
        ));
      }
    }
    for (final c in cryptoList) {
      if (c.buyPrice > 0) {
        positions.add((
          c.coinSymbol,
          (c.currentPrice / c.buyPrice - 1) * 100,
          AppColors.chartCrypto,
        ));
      }
    }
    for (final a in assetsList) {
      if (a.buyPrice > 0) {
        positions.add((
          a.description,
          (a.currentValue / a.buyPrice - 1) * 100,
          AppColors.chartPhysical,
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top & Flop Positionen'),
        centerTitle: false,
      ),
      body: positions.isEmpty
          ? Center(
              child: Text(
                'Noch keine Investmentpositionen mit Kaufpreis',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.45), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            )
          : _TopFlopBody(positions: positions),
    );
  }
}

class _TopFlopBody extends StatelessWidget {
  const _TopFlopBody({required this.positions});
  final List<(String, double, Color)> positions;

  @override
  Widget build(BuildContext context) {
    final sorted = [...positions]..sort((a, b) => b.$2.compareTo(a.$2));
    final winners = sorted.where((p) => p.$2 >= 0).toList();
    final losers = sorted.where((p) => p.$2 < 0).toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (winners.isNotEmpty) ...[
          _SectionHeader(
            label: 'Gewinner',
            color: AppColors.positive(context),
            icon: Icons.arrow_upward,
          ),
          const SizedBox(height: 8),
          _PositionList(positions: winners),
          const SizedBox(height: 20),
        ],
        if (losers.isNotEmpty) ...[
          _SectionHeader(
            label: 'Verlierer',
            color: AppColors.secondary(context),
            icon: Icons.arrow_downward,
          ),
          const SizedBox(height: 8),
          _PositionList(positions: losers),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PositionList extends StatelessWidget {
  const _PositionList({required this.positions});
  final List<(String, double, Color)> positions;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: positions.asMap().entries.map((entry) {
          final i = entry.key;
          final (name, pct, dotColor) = entry.value;
          final isPos = pct >= 0;
          final c = isPos
              ? AppColors.positive(context)
              : AppColors.secondary(context);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                            color: onSurface.withValues(alpha: 0.75),
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${isPos ? '+' : ''}${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: c,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (i < positions.length - 1)
                Divider(
                    height: 1,
                    indent: 30,
                    color: outline.withValues(alpha: 0.1)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
