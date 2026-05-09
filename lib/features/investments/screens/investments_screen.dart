import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/update_icon_button.dart';
import '../../crypto/screens/crypto_screen.dart';
import '../../etf_stocks/screens/etf_screen.dart';
import '../../festgeld/screens/festgeld_screen.dart';
import '../../home/providers/home_providers.dart';
import '../../physical_assets/screens/assets_screen.dart';

/// Set to the desired tab index before navigating to /investments.
/// Resets to null after the tab is applied (one-shot).
final investmentsTabProvider = StateProvider<int?>((ref) => null);

class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshInvestments() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    try {
      final cryptoList = ref.read(cryptoStreamProvider).valueOrNull ??
          await ref.read(cryptoStreamProvider.future);
      final etfList = ref.read(etfStreamProvider).valueOrNull ??
          await ref.read(etfStreamProvider.future);
      final assetsList = ref.read(assetsStreamProvider).valueOrNull ??
          await ref.read(assetsStreamProvider.future);

      final updated = await ref.read(priceRefreshServiceProvider).refreshAll(
            cryptoList: cryptoList ?? const [],
            etfList: etfList ?? const [],
            assetsList: assetsList ?? const [],
          );

      ref.invalidate(festgeldStreamProvider);
      ref.invalidate(netWorthHistoryProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$updated Kurse aktualisiert'),
        duration: const Duration(seconds: 3),
      ));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestedTab = ref.watch(investmentsTabProvider);

    if (requestedTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabController.animateTo(requestedTab.clamp(0, 3));
        // Reset so the next tap always registers as a change
        ref.read(investmentsTabProvider.notifier).state = null;
      });
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        automaticallyImplyLeading: false,
        leading: const SizedBox.shrink(),
        leadingWidth: 52,
        title: const Text('Investments'),
        actions: [
          UpdateIconButton(
            isLoading: _refreshing,
            onPressed: _refreshInvestments,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Festgeld'),
            Tab(text: 'ETF & Aktien'),
            Tab(text: 'Krypto'),
            Tab(text: 'Assets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FestgeldTabBody(),
          EtfTabBody(),
          CryptoTabBody(),
          AssetsTabBody(),
        ],
      ),
    );
  }
}
