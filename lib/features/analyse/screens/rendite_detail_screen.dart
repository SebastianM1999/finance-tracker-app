import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/providers/home_providers.dart';

class RenditeDetailScreen extends ConsumerWidget {
  const RenditeDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final etfList = ref.watch(etfStreamProvider).valueOrNull ?? [];
    final cryptoList = ref.watch(cryptoStreamProvider).valueOrNull ?? [];
    final assetsList = ref.watch(assetsStreamProvider).valueOrNull ?? [];

    double etfInvested = 0, etfCurrent = 0;
    for (final e in etfList) {
      etfInvested += e.buyValue;
      etfCurrent += e.currentValue;
    }
    double cryptoInvested = 0, cryptoCurrent = 0;
    for (final c in cryptoList) {
      cryptoInvested += c.buyValue;
      cryptoCurrent += c.currentValue;
    }
    double assetsInvested = 0, assetsCurrent = 0;
    for (final a in assetsList) {
      assetsInvested += a.buyPrice;
      assetsCurrent += a.currentValue;
    }

    final totalInvested = etfInvested + cryptoInvested + assetsInvested;
    final totalCurrent = etfCurrent + cryptoCurrent + assetsCurrent;
    final totalPnl = totalCurrent - totalInvested;
    final totalPct =
        totalInvested == 0 ? 0.0 : (totalPnl / totalInvested) * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investitionsrendite'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded,
                color: onSurface.withValues(alpha: 0.5)),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _TotalHeader(
            invested: totalInvested,
            current: totalCurrent,
            pnl: totalPnl,
            pct: totalPct,
          ),
          const SizedBox(height: 20),
          if (etfList.isNotEmpty) ...[
            _CategorySection(
              title: 'ETF & Aktien',
              color: AppColors.chartEtf,
              invested: etfInvested,
              current: etfCurrent,
              positions: etfList
                  .map((e) => (
                        e.ticker ?? e.name,
                        e.buyValue,
                        e.currentValue,
                        AppColors.chartEtf,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (cryptoList.isNotEmpty) ...[
            _CategorySection(
              title: 'Krypto',
              color: AppColors.chartCrypto,
              invested: cryptoInvested,
              current: cryptoCurrent,
              positions: cryptoList
                  .map((c) => (
                        c.coinSymbol,
                        c.buyValue,
                        c.currentValue,
                        AppColors.chartCrypto,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (assetsList.isNotEmpty) ...[
            _CategorySection(
              title: 'Sachwerte',
              color: AppColors.chartPhysical,
              invested: assetsInvested,
              current: assetsCurrent,
              positions: assetsList
                  .map((a) => (
                        a.description,
                        a.buyPrice,
                        a.currentValue,
                        AppColors.chartPhysical,
                      ))
                  .toList(),
            ),
          ],
          if (etfList.isEmpty && cryptoList.isEmpty && assetsList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  'Noch keine Investmentpositionen',
                  style: TextStyle(
                      color: onSurface.withValues(alpha: 0.45), fontSize: 14),
                ),
              ),
            ),
        ],
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
        title: Text('Wie wird die Rendite berechnet?',
            style: TextStyle(
                color: onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Die Rendite (ROI) wird berechnet als:\n\n'
          '  ROI = (aktueller Wert / Kaufwert − 1) × 100\n\n'
          'Kaufwert = Kaufpreis × Anzahl\n'
          'Aktueller Wert = aktueller Preis × Anzahl\n\n'
          'Nur Positionen mit einem Kaufpreis > 0 werden berücksichtigt.',
          style: TextStyle(
              color: onSurface.withValues(alpha: 0.7), fontSize: 13, height: 1.6),
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

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({
    required this.invested,
    required this.current,
    required this.pnl,
    required this.pct,
  });
  final double invested, current, pnl, pct;

  @override
  Widget build(BuildContext context) {
    final isPos = pnl >= 0;
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Cell(
                    label: 'Investiert',
                    value: CurrencyFormatter.format(invested),
                    color: onSurface),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: outline.withValues(alpha: 0.2)),
              Expanded(
                child: _Cell(
                    label: 'Aktuell',
                    value: CurrencyFormatter.format(current),
                    color: onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: outline.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPos ? Icons.arrow_upward : Icons.arrow_downward,
                color: c,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${isPos ? '+' : ''}${CurrencyFormatter.format(pnl)}  (${isPos ? '+' : ''}${pct.toStringAsFixed(2)}%)',
                style: TextStyle(
                    color: c, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: onSurface.withValues(alpha: 0.45), fontSize: 11)),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.color,
    required this.invested,
    required this.current,
    required this.positions,
  });

  final String title;
  final Color color;
  final double invested, current;
  final List<(String, double, double, Color)> positions;

  @override
  Widget build(BuildContext context) {
    final pnl = current - invested;
    final pct =
        invested == 0 ? 0.0 : (pnl / invested) * 100;
    final isPos = pnl >= 0;
    final pnlColor =
        isPos ? AppColors.positive(context) : AppColors.secondary(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Text(
                  '${isPos ? '+' : ''}${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: pnlColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: outline.withValues(alpha: 0.12)),
          ...positions.map((p) {
            final (name, buyVal, curVal, dotColor) = p;
            final posIsPos = curVal >= buyVal;
            final posPct = buyVal == 0
                ? 0.0
                : ((curVal - buyVal) / buyVal) * 100;
            final posColor = posIsPos
                ? AppColors.positive(context)
                : AppColors.secondary(context);
            final barFraction =
                buyVal == 0 ? 0.0 : (curVal / buyVal).clamp(0.0, 2.0) / 2.0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: dotColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name,
                            style: TextStyle(
                                color: onSurface.withValues(alpha: 0.7),
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '${posIsPos ? '+' : ''}${posPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: posColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 4,
                      color: outline.withValues(alpha: 0.1),
                      child: FractionallySizedBox(
                        widthFactor: barFraction,
                        alignment: Alignment.centerLeft,
                        child: Container(color: posColor.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
