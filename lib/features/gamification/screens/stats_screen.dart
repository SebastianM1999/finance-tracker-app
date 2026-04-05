import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/providers/home_providers.dart';
import '../providers/gamification_providers.dart';


class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(gamificationProfileProvider);

    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Drag handle + title ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: outline.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meine Statistiken',
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deine Finanzen im Überblick',
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (profile) {
                if (profile == null) {
                  return Center(
                    child: Text('Noch keine Daten',
                        style: theme.textTheme.bodyMedium),
                  );
                }

                final daysActive =
                    DateTime.now().difference(profile.createdAt).inDays + 1;
                final badgeCount = profile.unlockedBadgeIds.length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
              // ── Quick stat tiles ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Abzeichen',
                      value: '$badgeCount',
                      sub: 'von 104',
                      icon: Icons.military_tech_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Aktiv seit',
                      value: '$daysActive',
                      sub: daysActive == 1 ? 'Tag' : 'Tagen',
                      icon: Icons.calendar_today_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Updates',
                      value: '${profile.updateCount}',
                      sub: 'insgesamt',
                      icon: Icons.refresh_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 28),

              // ── Portfolio allocation pie chart ─────────────────────────────
              const _SectionLabel(label: 'Portfolio-Aufteilung'),
              const SizedBox(height: 12),
              const _AllocationPieChart(),
              const SizedBox(height: 28),

                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}


// ── Portfolio allocation donut chart ──────────────────────────────────────────

class _AllocationPieChart extends ConsumerStatefulWidget {
  const _AllocationPieChart();

  @override
  ConsumerState<_AllocationPieChart> createState() =>
      _AllocationPieChartState();
}

class _AllocationPieChartState extends ConsumerState<_AllocationPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final giro = ref.watch(giroTotalProvider);
    final festgeld = ref.watch(festgeldTotalProvider);
    final etf = ref.watch(etfTotalProvider);
    final crypto = ref.watch(cryptoTotalProvider);
    final assets = ref.watch(assetsTotalProvider);
    final schulden = ref.watch(schuldenTotalProvider);

    const categories = [
      ('Giro', AppColors.chartGiro),
      ('Festgeld', AppColors.chartFestgeld),
      ('ETF & Aktien', AppColors.chartEtf),
      ('Krypto', AppColors.chartCrypto),
      ('Sachwerte', AppColors.chartPhysical),
    ];
    final values = [giro, festgeld, etf, crypto, assets];
    final total = values.fold(0.0, (s, v) => s + (v > 0 ? v : 0));

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outline.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: Text(
            'Noch keine Positionen vorhanden',
            style: TextStyle(color: onSurface.withValues(alpha: 0.38), fontSize: 13),
          ),
        ),
      );
    }

    final sections = List.generate(categories.length, (i) {
      final value = values[i];
      if (value <= 0) {
        return PieChartSectionData(value: 0.001, showTitle: false, radius: 0);
      }
      final isTouched = i == _touchedIndex;
      return PieChartSectionData(
        value: value,
        color: categories[i].$2,
        radius: isTouched ? 60 : 52,
        showTitle: false,
      );
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 60,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent) return;
                        final tapped =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        setState(() {
                          _touchedIndex = _touchedIndex == tapped ? -1 : tapped;
                        });
                      },
                    ),
                  ),
                ),
                // Label in the donut centre
                AnimatedOpacity(
                  opacity:
                      (_touchedIndex >= 0 && _touchedIndex < categories.length)
                          ? 1.0
                          : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: _touchedIndex >= 0 && _touchedIndex < categories.length
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              categories[_touchedIndex].$1,
                              style: TextStyle(
                                color: categories[_touchedIndex].$2,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              CurrencyFormatter.format(values[_touchedIndex]),
                              style: TextStyle(
                                color: onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(values[_touchedIndex] / total * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: onSurface.withValues(alpha: 0.55),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: List.generate(categories.length, (i) {
              if (values[i] <= 0) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: categories[i].$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    categories[i].$1,
                    style: TextStyle(color: onSurface.withValues(alpha: 0.54), fontSize: 11),
                  ),
                ],
              );
            }),
          ),

          // Schulden badge
          if (schulden < 0) ...[
            const SizedBox(height: 10),
            Builder(builder: (ctx) {
              final sec = AppColors.secondary(ctx);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sec.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sec.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Abzgl. Schulden: ${CurrencyFormatter.format(schulden)}',
                  style: TextStyle(
                    color: sec,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}


// ── Gamification card ─────────────────────────────────────────────────────────

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          Text(sub,
              style: TextStyle(color: onSurface.withValues(alpha: 0.38), fontSize: 11)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: onSurface.withValues(alpha: 0.54), fontSize: 12)),
        ],
      ),
    );
  }
}
