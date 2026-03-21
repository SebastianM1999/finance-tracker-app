import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/profile_image_stub.dart'
    if (dart.library.js_interop) '../../../shared/widgets/profile_image_web.dart';
import '../../auth/providers/auth_providers.dart';
import '../../festgeld/models/festgeld.dart';
import '../../investments/screens/investments_screen.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final cryptoList = ref.read(cryptoStreamProvider).valueOrNull ?? [];
    final etfList = ref.read(etfStreamProvider).valueOrNull ?? [];
    final assetsList = ref.read(assetsStreamProvider).valueOrNull ?? [];

    final updated = await ref.read(priceRefreshServiceProvider).refreshAll(
          cryptoList: cryptoList,
          etfList: etfList,
          assetsList: assetsList,
        );

    ref.invalidate(giroStreamProvider);
    ref.invalidate(festgeldStreamProvider);
    ref.invalidate(schuldenStreamProvider);
    ref.invalidate(netWorthHistoryProvider);

    if (context.mounted && updated > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$updated Kurse aktualisiert'),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(context, ref),
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
                    Text('Schön dass du da bist!',
                        style: theme.textTheme.bodyMedium),
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
                    const _WelcomeBanner()
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 300.ms),
                    const _UpcomingMaturityBanner()
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 300.ms),
                    const SizedBox(height: 24),
                    Text('Kategorien', style: theme.textTheme.titleLarge)
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 300.ms),
                    const SizedBox(height: 10),
                    const _CategoryCards(),
                    const SizedBox(height: 24),
                    Text('Vermögensentwicklung',
                            style: theme.textTheme.titleLarge)
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 300.ms),
                    const SizedBox(height: 12),
                    const _MiniChart()
                        .animate()
                        .fadeIn(delay: 450.ms, duration: 300.ms),
                    const SizedBox(height: 24),
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
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(netWorth),
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ).animate(key: ValueKey(netWorth)).fadeIn(duration: 300.ms),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isPositive
                            ? AppColors.darkPositive
                            : AppColors.darkSecondary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${CurrencyFormatter.formatPnl(change.absolute)}  ${CurrencyFormatter.formatPercent(change.percent)}',
                    style: TextStyle(
                      color: isPositive
                          ? AppColors.darkPositive
                          : AppColors.darkSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'seit gestern',
                style:
                    TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
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
      (
        'Giro Konto',
        AppColors.gradientGiro,
        FontAwesomeIcons.buildingColumns,
        giro,
        AppRoutes.accounts,
        -1
      ),
      (
        'Festgeld',
        AppColors.gradientFestgeld,
        FontAwesomeIcons.piggyBank,
        festgeld,
        AppRoutes.investments,
        0
      ),
      (
        'ETF & Aktien',
        AppColors.gradientEtf,
        FontAwesomeIcons.chartLine,
        etf,
        AppRoutes.investments,
        1
      ),
      (
        'Krypto',
        AppColors.gradientCrypto,
        FontAwesomeIcons.coins,
        crypto,
        AppRoutes.investments,
        2
      ),
      (
        'Physische Assets',
        AppColors.gradientPhysical,
        FontAwesomeIcons.gem,
        assets,
        AppRoutes.investments,
        3
      ),
      (
        'Schulden',
        AppColors.gradientSchulden,
        FontAwesomeIcons.creditCard,
        schulden,
        AppRoutes.debts,
        -1
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final (label, gradient, icon, amount, route, investmentsTab) =
            categories[i];
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
                  child: FaIcon(icon, color: Colors.white, size: 18),
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
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(amount.abs()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: 200 + i * 60), duration: 300.ms)
            .slideY(
                begin: 0.15,
                end: 0,
                delay: Duration(milliseconds: 200 + i * 60),
                duration: 300.ms);
      },
    );
  }
}

// ── Welcome / Onboarding Banner ───────────────────────────────────────────────

class _WelcomeBanner extends ConsumerWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show only when all streams are loaded and everything is still empty
    final allLoaded = ref.watch(giroStreamProvider).hasValue &&
        ref.watch(festgeldStreamProvider).hasValue &&
        ref.watch(etfStreamProvider).hasValue &&
        ref.watch(cryptoStreamProvider).hasValue &&
        ref.watch(assetsStreamProvider).hasValue &&
        ref.watch(schuldenStreamProvider).hasValue;

    if (!allLoaded) return const SizedBox.shrink();

    final netWorth = ref.watch(netWorthProvider);
    if (netWorth != 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E2530), Color(0xFF161B22)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.darkPrimary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.waving_hand_outlined,
                      color: AppColors.darkPrimary, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Willkommen bei FinTrack!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Füge deine ersten Positionen hinzu, um dein Gesamtvermögen zu tracken.',
              style: TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OnboardingButton(
                    label: 'Konto hinzufügen',
                    icon: Icons.account_balance_outlined,
                    onTap: () => context.go(AppRoutes.accounts),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OnboardingButton(
                    label: 'Investment hinzufügen',
                    icon: Icons.trending_up_outlined,
                    onTap: () => context.go(AppRoutes.investments),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingButton extends StatelessWidget {
  const _OnboardingButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.darkPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppColors.darkPrimary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.darkPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.darkPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upcoming Festgeld Maturity Notifications ──────────────────────────────────

class _UpcomingMaturityBanner extends ConsumerStatefulWidget {
  const _UpcomingMaturityBanner();

  @override
  ConsumerState<_UpcomingMaturityBanner> createState() =>
      _UpcomingMaturityBannerState();
}

class _UpcomingMaturityBannerState
    extends ConsumerState<_UpcomingMaturityBanner>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late final AnimationController _chevronController;

  @override
  void initState() {
    super.initState();
    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1, // starts expanded
    );
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _chevronController.forward();
    } else {
      _chevronController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch stream directly so deletions propagate immediately
    final allItems = ref.watch(festgeldStreamProvider).valueOrNull ?? [];
    final upcoming = (allItems.where((f) => f.daysRemaining < 8).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate)));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable section header
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Text(
                  'Fälligkeiten',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.darkWarning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${upcoming.length}',
                    style: const TextStyle(
                      color: AppColors.darkWarning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                RotationTransition(
                  turns: Tween(begin: 0.5, end: 0.0).animate(CurvedAnimation(
                    parent: _chevronController,
                    curve: Curves.easeInOut,
                  )),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.darkTextSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          // Animated card list
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      const SizedBox(height: 10),
                      ...upcoming.asMap().entries.map((entry) {
                        final i = entry.key;
                        final f = entry.value;
                        return _MaturityCard(item: f)
                            .animate()
                            .fadeIn(
                                delay: Duration(milliseconds: i * 60),
                                duration: 280.ms)
                            .slideX(
                                begin: -0.04,
                                end: 0,
                                delay: Duration(milliseconds: i * 60),
                                duration: 280.ms);
                      }),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MaturityCard extends ConsumerWidget {
  const _MaturityCard({required this.item});
  final Festgeld item;


  /// Mirrors _FestgeldCard._urgencyColor — null means "not urgent yet"
  Color? _urgencyColor(bool isExpired, double progress) {
    if (isExpired) return AppColors.darkSecondary;
    if (progress >= 0.90) return const Color(0xFF4FC770);
    if (progress >= 0.75) return AppColors.darkPositive;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpired = item.daysRemaining < 0;
    final urgency = _urgencyColor(isExpired, item.progress);
    final borderColor = urgency ?? AppColors.darkPrimary;
    final daysLabel = DateFormatter.daysRemaining(item.endDate);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(investmentsTabProvider.notifier).state = 0;
          context.go(AppRoutes.investments);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Gradient pig icon — identical to Festgeld tab card
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.gradientFestgeld,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.savings_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              // Bank name + amounts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.bankName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.format(item.amount),
                          style: const TextStyle(
                            color: AppColors.darkTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Text(' → ',
                            style: TextStyle(
                                color: AppColors.darkTextSecondary,
                                fontSize: 12)),
                        Text(
                          CurrencyFormatter.format(item.projectedPayout),
                          style: const TextStyle(
                            color: AppColors.darkPositive,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge — colored when urgent, plain text otherwise
              if (urgency != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgency.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    daysLabel,
                    style: TextStyle(
                      color: urgency,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Text(
                  daysLabel,
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
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
                                    e.key.toDouble(), e.value.totalNetWorth))
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
