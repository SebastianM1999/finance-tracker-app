import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/profile_image_stub.dart'
    if (dart.library.js_interop) '../../../shared/widgets/profile_image_web.dart';
import '../../auth/providers/auth_providers.dart';
import '../../giro/models/giro_account.dart';
import '../../investments/screens/investments_screen.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(giroStreamProvider);
          ref.invalidate(festgeldStreamProvider);
          ref.invalidate(etfStreamProvider);
          ref.invalidate(cryptoStreamProvider);
          ref.invalidate(assetsStreamProvider);
          ref.invalidate(schuldenStreamProvider);
          ref.invalidate(netWorthHistoryProvider);
          // Wait for at least one to refresh
          await ref.read(giroStreamProvider.future).catchError((_) => <GiroAccount>[]);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              toolbarHeight: 72,
              title: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hallo, ${user?.displayName.split(' ').first ?? 'Nutzer'} 👋',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text('Gesamtvermögen', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, top: 12),
                  child: _UserAvatar(user: user),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _NetWorthHero()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0, duration: 400.ms),
                    const SizedBox(height: 16),
                    const _UpcomingMaturityBanner()
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 300.ms),
                    const SizedBox(height: 24),
                    Text('Kategorien', style: theme.textTheme.titleLarge)
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 300.ms),
                    const SizedBox(height: 16),
                    const _CategoryCards(),
                    const SizedBox(height: 24),
                    Text('Vermögensentwicklung', style: theme.textTheme.titleLarge)
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 300.ms),
                    const SizedBox(height: 16),
                    const _MiniChart()
                        .animate()
                        .fadeIn(delay: 450.ms, duration: 300.ms),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Net Worth Hero ────────────────────────────────────────────────────────────

class _NetWorthHero extends ConsumerWidget {
  const _NetWorthHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorth = ref.watch(netWorthProvider);
    final change = ref.watch(netWorthChangeProvider);
    final isPositive = change.absolute >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2530), Color(0xFF161B22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkPrimary.withValues(alpha: 0.15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gesamtvermögen',
            style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(netWorth),
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ).animate(key: ValueKey(netWorth)).fadeIn(duration: 300.ms),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.darkPositive : AppColors.darkSecondary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${CurrencyFormatter.formatPnl(change.absolute)}  ${CurrencyFormatter.formatPercent(change.percent)}',
                  style: TextStyle(
                    color: isPositive ? AppColors.darkPositive : AppColors.darkSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'seit gestern',
                style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Category Cards ────────────────────────────────────────────────────────────

class _CategoryCards extends ConsumerWidget {
  const _CategoryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giro = ref.watch(giroTotalProvider);
    final festgeld = ref.watch(festgeldTotalProvider);
    final etf = ref.watch(etfTotalProvider);
    final crypto = ref.watch(cryptoTotalProvider);
    final assets = ref.watch(assetsTotalProvider);
    final schulden = ref.watch(schuldenTotalProvider);

    // (label, gradient, icon, amount, route, investmentsTab)
    // investmentsTab = -1 means not an investments sub-tab
    final categories = [
      ('Giro Konto', AppColors.gradientGiro, Icons.account_balance_outlined, giro,
          AppRoutes.accounts, -1),
      ('Festgeld', AppColors.gradientFestgeld, Icons.lock_clock_outlined, festgeld,
          AppRoutes.investments, 0),
      ('ETF & Aktien', AppColors.gradientEtf, Icons.trending_up_outlined, etf,
          AppRoutes.investments, 1),
      ('Krypto', AppColors.gradientCrypto, Icons.currency_bitcoin_outlined, crypto,
          AppRoutes.investments, 2),
      ('Physische Assets', AppColors.gradientPhysical, Icons.inventory_2_outlined, assets,
          AppRoutes.investments, 3),
      ('Schulden', AppColors.gradientSchulden, Icons.balance_outlined, schulden,
          AppRoutes.debts, -1),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final (label, gradient, icon, amount, route, investmentsTab) = categories[i];
        return GestureDetector(
          onTap: () {
            if (investmentsTab >= 0) {
              ref.read(investmentsTabProvider.notifier).state = investmentsTab;
            }
            context.go(route);
          },

          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(amount.abs()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: 200 + i * 60), duration: 300.ms)
            .slideY(begin: 0.15, end: 0,
                delay: Duration(milliseconds: 200 + i * 60), duration: 300.ms);
      },
    );
  }
}

// ── Upcoming Festgeld Maturity Banner ─────────────────────────────────────────

class _UpcomingMaturityBanner extends ConsumerWidget {
  const _UpcomingMaturityBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingMaturitiesProvider);
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkWarning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkWarning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              color: AppColors.darkWarning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '⏰ ${next.bankName} – ${DateFormatter.daysRemaining(next.endDate)} (${CurrencyFormatter.format(next.amount)})',
              style: const TextStyle(
                  color: AppColors.darkWarning,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini Net Worth Chart (tappable → VerlaufScreen) ──────────────────────────

class _MiniChart extends ConsumerWidget {
  const _MiniChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(netWorthHistoryProvider).valueOrNull ?? [];

    return GestureDetector(
      onTap: () => context.push(AppRoutes.verlauf),
      child: Container(
        height: 180,
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1M',
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Verlauf ansehen',
                        style: TextStyle(
                          color: AppColors.darkPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios,
                          size: 10, color: AppColors.darkPrimary),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: history.length < 2
                  ? const Center(
                      child: Text(
                        'Noch keine Verlaufsdaten',
                        style: TextStyle(
                            color: AppColors.darkTextSecondary, fontSize: 13),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: history
                                .asMap()
                                .entries
                                .map((e) => FlSpot(
                                    e.key.toDouble(),
                                    e.value.totalNetWorth))
                                .toList(),
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
          ],
        ),
      ),
    );
  }
}

// ── User Avatar ───────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl as String?;
    final initial =
        (user?.displayName as String? ?? 'S').substring(0, 1).toUpperCase();

    if (photoUrl != null) {
      return ClipOval(child: buildProfileImage(photoUrl, 36));
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.darkPrimary,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}
