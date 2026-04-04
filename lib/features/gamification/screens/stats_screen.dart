import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../home/providers/home_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/gamification_providers.dart';

// ── Category colors (brighter than gradient starts for better chart visibility)
const _cGiro = Color(0xFF7B8FFF);
const _cFestgeld = Color(0xFFE090E0);
const _cEtf = Color(0xFF4DB8F5);
const _cCrypto = Color(0xFFEE7AA0);
const _cPhysical = Color(0xFF4DD87C);

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(gamificationProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        title: const Text('Meine Statistiken'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (profile) {
          if (profile == null) {
            return Center(
              child:
                  Text('Noch keine Daten', style: theme.textTheme.bodyMedium),
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
                      sub: 'von 32',
                      icon: Icons.military_tech_outlined,
                      color: AppColors.darkPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Aktiv seit',
                      value: '$daysActive',
                      sub: daysActive == 1 ? 'Tag' : 'Tagen',
                      icon: Icons.calendar_today_outlined,
                      color: AppColors.darkPrimary,
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
                      color: AppColors.darkPrimary,
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

              // ── PRO Analyse ────────────────────────────────────────────────
              _ProSectionHeader(),
              const SizedBox(height: 12),
              const _ProCard(
                title: 'Investitions-Profitabilität',
                description: 'Gewinn/Verlust je Position',
                icon: Icons.bar_chart_outlined,
                child: _ProfitabilityCard(),
              ),
              const SizedBox(height: 12),
              const _ProCard(
                title: 'Risikoprofil',
                description: 'Einschätzung deiner Risikobereitschaft',
                icon: Icons.shield_outlined,
                child: _RiskProfileCard(),
              ),
              const SizedBox(height: 12),
              const _ProCard(
                title: 'Top & Flop Positionen',
                description: 'Beste und schlechteste Investments',
                icon: Icons.emoji_events_outlined,
                child: _TopFlopCard(),
              ),
              const SizedBox(height: 12),
              const _ProCard(
                title: 'Kategorie-Entwicklung',
                description: 'Verlauf je Anlageklasse (6 Monate)',
                icon: Icons.stacked_line_chart_outlined,
                child: _CategoryGrowthCard(),
              ),
            ],
          );
        },
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

// ── PRO section header ────────────────────────────────────────────────────────

class _ProSectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('PRO Analyse', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD4A017), Color(0xFFB8860B)],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'PRO',
            style: TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── PRO card wrapper ──────────────────────────────────────────────────────────

class _ProCard extends ConsumerWidget {
  const _ProCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);

    return GestureDetector(
      onTap: isPro ? null : () => _showProSheet(context),
      child: Stack(
        children: [
          child,
          if (!isPro)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: const Color(0xCC0D0F14),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.lock_outline,
                              color: Colors.white54, size: 28),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4A017), Color(0xFFB8860B)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO FEATURE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showProSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4A017), Color(0xFFB8860B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.black, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'FinTrack PRO',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Diese Analyse ist Teil von FinTrack Pro.\nWir arbeiten daran — bald verfügbar!',
              style:
                  TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Verstanden',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
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
      ('Giro', _cGiro),
      ('Festgeld', _cFestgeld),
      ('ETF & Aktien', _cEtf),
      ('Krypto', _cCrypto),
      ('Sachwerte', _cPhysical),
    ];
    final values = [giro, festgeld, etf, crypto, assets];
    final total = values.fold(0.0, (s, v) => s + (v > 0 ? v : 0));

    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: Text(
            'Noch keine Positionen vorhanden',
            style: TextStyle(color: Colors.white38, fontSize: 13),
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
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(values[_touchedIndex] / total * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
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
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              );
            }),
          ),

          // Schulden badge
          if (schulden < 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.darkSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.darkSecondary.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Abzgl. Schulden: ${CurrencyFormatter.format(schulden)}',
                style: const TextStyle(
                  color: AppColors.darkSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── PRO: Investitions-Profitabilität ──────────────────────────────────────────

class _ProfitabilityCard extends ConsumerWidget {
  const _ProfitabilityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etfList = ref.watch(etfStreamProvider).valueOrNull ?? [];
    final cryptoList = ref.watch(cryptoStreamProvider).valueOrNull ?? [];
    final assetsList = ref.watch(assetsStreamProvider).valueOrNull ?? [];

    final positions = <(String, double, Color)>[];
    for (final e in etfList) {
      if (e.buyPrice > 0) {
        positions.add((
          e.ticker ?? e.name,
          (e.currentPrice / e.buyPrice - 1) * 100,
          _cEtf
        ));
      }
    }
    for (final c in cryptoList) {
      if (c.buyPrice > 0) {
        positions.add(
            (c.coinSymbol, (c.currentPrice / c.buyPrice - 1) * 100, _cCrypto));
      }
    }
    for (final a in assetsList) {
      if (a.buyPrice > 0) {
        positions.add((
          a.description,
          (a.currentValue / a.buyPrice - 1) * 100,
          _cPhysical
        ));
      }
    }
    positions.sort((a, b) => b.$2.compareTo(a.$2));

    if (positions.isEmpty) return _emptyCard('Noch keine Investmentpositionen');

    final maxAbs =
        positions.fold(0.0, (m, p) => p.$2.abs() > m ? p.$2.abs() : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Investitions-Profitabilität',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...positions.map((p) {
            final (name, pct, color) = p;
            final isPos = pct >= 0;
            final barColor =
                isPos ? AppColors.darkPositive : AppColors.darkSecondary;
            final barFrac = maxAbs == 0 ? 0.0 : pct.abs() / maxAbs;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(name,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(builder: (_, constraints) {
                      final half = constraints.maxWidth / 2;
                      return Stack(
                        children: [
                          Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Positioned(
                            left: isPos ? half : half - half * barFrac,
                            child: Container(
                              width: half * barFrac,
                              height: 18,
                              decoration: BoxDecoration(
                                color: barColor.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Positioned(
                            left: half - 0.5,
                            child: Container(
                                width: 1, height: 18, color: Colors.white12),
                          ),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${isPos ? '+' : ''}${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: barColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── PRO: Risikoprofil ─────────────────────────────────────────────────────────

class _RiskProfileCard extends ConsumerWidget {
  const _RiskProfileCard();

  static (String, Color) _label(double score) {
    if (score < 0.15) return ('Konservativ', Color(0xFF3F8ACB));
    if (score < 0.35) return ('Ausgewogen', AppColors.darkPositive);
    if (score < 0.55) return ('Wachstum', Color(0xFFF39C12));
    if (score < 0.75) return ('Offensiv', Color(0xFFE67E22));
    return ('Spekulativ', AppColors.darkSecondary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giro = ref.watch(giroTotalProvider);
    final festgeld = ref.watch(festgeldTotalProvider);
    final etf = ref.watch(etfTotalProvider);
    final crypto = ref.watch(cryptoTotalProvider);
    final assets = ref.watch(assetsTotalProvider);

    final positives = [giro, festgeld, etf, crypto, assets]
        .map((v) => v < 0 ? 0.0 : v)
        .toList();
    final total = positives.fold(0.0, (s, v) => s + v);

    if (total <= 0)
      return _emptyCard('Noch keine Positionen für Risikoanalyse');

    const weights = [0.1, 0.0, 0.5, 1.0, 0.3];
    final riskScore = List.generate(5, (i) => positives[i] * weights[i])
            .fold(0.0, (s, v) => s + v) /
        total;

    final (label, labelColor) = _label(riskScore);

    const names = ['Giro', 'Festgeld', 'ETF & Aktien', 'Krypto', 'Sachwerte'];
    const colors = [_cGiro, _cFestgeld, _cEtf, _cCrypto, _cPhysical];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Risikoprofil',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: labelColor.withValues(alpha: 0.4)),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: labelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color(0xFF3F8ACB),
                  AppColors.darkPositive,
                  Color(0xFFF39C12),
                  Color(0xFFE67E22),
                  AppColors.darkSecondary,
                ]),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: riskScore.clamp(0.02, 0.98),
            alignment: Alignment.centerLeft,
            child: Align(
              alignment: Alignment.topRight,
              child: Container(width: 2, height: 8, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 2),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Konservativ',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('Spekulativ',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(5, (i) {
            if (positives[i] <= 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: colors[i], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(names[i],
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ),
                  Text('${(positives[i] / total * 100).toStringAsFixed(1)}%',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── PRO: Top & Flop ───────────────────────────────────────────────────────────

class _TopFlopCard extends ConsumerWidget {
  const _TopFlopCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etfList = ref.watch(etfStreamProvider).valueOrNull ?? [];
    final cryptoList = ref.watch(cryptoStreamProvider).valueOrNull ?? [];
    final assetsList = ref.watch(assetsStreamProvider).valueOrNull ?? [];

    final positions = <(String, double, Color)>[];
    for (final e in etfList) {
      if (e.buyPrice > 0) {
        positions.add((
          e.ticker ?? e.name,
          (e.currentPrice / e.buyPrice - 1) * 100,
          _cEtf
        ));
      }
    }
    for (final c in cryptoList) {
      if (c.buyPrice > 0) {
        positions.add(
            (c.coinSymbol, (c.currentPrice / c.buyPrice - 1) * 100, _cCrypto));
      }
    }
    for (final a in assetsList) {
      if (a.buyPrice > 0) {
        positions.add((
          a.description,
          (a.currentValue / a.buyPrice - 1) * 100,
          _cPhysical
        ));
      }
    }

    if (positions.isEmpty) return _emptyCard('Noch keine Investmentpositionen');

    positions.sort((a, b) => b.$2.compareTo(a.$2));
    final top = positions.take(3).toList();
    final flop = positions.reversed.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.arrow_upward,
                      color: AppColors.darkPositive, size: 14),
                  SizedBox(width: 4),
                  Text('Top',
                      style: TextStyle(
                          color: AppColors.darkPositive,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                ...top.map((p) => _TopFlopRow(
                    name: p.$1, pct: p.$2, dotColor: p.$3, isTop: true)),
              ],
            ),
          ),
          Container(
              width: 1,
              color: Colors.white10,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.arrow_downward,
                      color: AppColors.darkSecondary, size: 14),
                  SizedBox(width: 4),
                  Text('Flop',
                      style: TextStyle(
                          color: AppColors.darkSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                ...flop.map((p) => _TopFlopRow(
                    name: p.$1, pct: p.$2, dotColor: p.$3, isTop: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopFlopRow extends StatelessWidget {
  const _TopFlopRow(
      {required this.name,
      required this.pct,
      required this.dotColor,
      required this.isTop});
  final String name;
  final double pct;
  final Color dotColor;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final c = isTop ? AppColors.darkPositive : AppColors.darkSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
            style:
                TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── PRO: Kategorie-Entwicklung ────────────────────────────────────────────────

class _CategoryGrowthCard extends ConsumerWidget {
  const _CategoryGrowthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(netWorthRangeProvider(180));

    return historyAsync.when(
      loading: () => _emptyCard('Lade Verlaufsdaten…'),
      error: (_, __) => _emptyCard('Fehler beim Laden'),
      data: (snapshots) {
        if (snapshots.length < 2) {
          return _emptyCard('Noch zu wenige Verlaufsdaten');
        }

        final lineConfigs = [
          ('Giro', snapshots.map((s) => s.giro).toList(), _cGiro),
          ('Festgeld', snapshots.map((s) => s.festgeld).toList(), _cFestgeld),
          ('ETF', snapshots.map((s) => s.etfStocks).toList(), _cEtf),
          ('Krypto', snapshots.map((s) => s.crypto).toList(), _cCrypto),
          ('Sachwerte', snapshots.map((s) => s.physical).toList(), _cPhysical),
        ];

        final barData = lineConfigs.map((cfg) {
          final (_, values, color) = cfg;
          return LineChartBarData(
            spots: values
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: color,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          );
        }).toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kategorie-Entwicklung',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text('Letzte 6 Monate',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.white.withValues(alpha: 0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: barData,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: lineConfigs.map((cfg) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 16,
                          height: 3,
                          color: cfg.$3,
                          margin: const EdgeInsets.only(right: 4)),
                      Text(cfg.$1,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared empty-state card ───────────────────────────────────────────────────

Widget _emptyCard(String message) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white10),
    ),
    child: Center(
      child: Text(message,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
          textAlign: TextAlign.center),
    ),
  );
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
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
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
