import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/price_service.dart';
import '../../settings/providers/settings_providers.dart';
import '../models/watchlist_item.dart';
import '../providers/watchlist_providers.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  // itemId → live price being fetched
  final Map<String, double?> _livePrices = {};
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  Future<void> _refreshAll() async {
    final items = ref.read(watchlistStreamProvider).valueOrNull ?? [];
    for (final item in items) {
      if (!_loading.contains(item.id)) _fetchPrice(item);
    }
  }

  Future<void> _fetchPrice(WatchlistItem item) async {
    if (_loading.contains(item.id)) return;
    setState(() => _loading.add(item.id));

    PriceResult? result;
    if (item.type == 'crypto') {
      result = await PriceService.fetchCryptoPrice(item.symbol, item.name);
    } else {
      result = await PriceService.fetchStockOrEtfPrice(
        item.symbol,
        isEtf: item.type == 'etf',
      );
    }

    if (!mounted) return;
    final price = result?.price;
    setState(() {
      _livePrices[item.id] = price;
      _loading.remove(item.id);
    });

    // Persist to Firestore + check alert
    if (price != null) {
      final repo = ref.read(watchlistRepositoryProvider);
      final updated = item.copyWith(
        lastKnownPrice: price,
        lastPriceUpdate: DateTime.now(),
      );
      await repo.update(updated);

      // Fire notification if target reached
      if (item.targetPrice != null && price >= item.targetPrice!) {
        await NotificationService.instance.showWatchlistAlert(
          symbol: item.symbol,
          name: item.name,
          currentPrice: price,
          targetPrice: item.targetPrice!,
        );
      }
    }
  }

  Future<void> _deleteItem(WatchlistItem item) async {
    await ref.read(watchlistRepositoryProvider).delete(item.id);
    setState(() {
      _livePrices.remove(item.id);
      _loading.remove(item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(watchlistStreamProvider);

    // Whenever the stream emits a new list, fetch prices for any item
    // that doesn't have a live price yet (covers newly added items too).
    ref.listen<AsyncValue<List<WatchlistItem>>>(
      watchlistStreamProvider,
      (_, next) {
        final items = next.valueOrNull ?? [];
        for (final item in items) {
          if (!_livePrices.containsKey(item.id) &&
              !_loading.contains(item.id)) {
            _fetchPrice(item);
          }
        }
      },
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _Header(onAdd: () async {
            final item = await showModalBottomSheet<WatchlistItem>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _AddWatchlistSheet(),
            );
            if (item != null && mounted) {
              await ref.read(watchlistRepositoryProvider).add(item);
              // Price fetch is triggered automatically by the stream listener
              // once Firestore assigns the real document ID.
            }
          }),
          Expanded(
            child: stream.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Fehler: $e',
                    style: const TextStyle(color: Colors.white54)),
              ),
              data: (items) {
                if (items.isEmpty) return const _EmptyState();
                return RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      final price = _livePrices[item.id] ??
                          item.lastKnownPrice;
                      final isLoading = _loading.contains(item.id);
                      return _WatchlistTile(
                        item: item,
                        currentPrice: price,
                        isLoading: isLoading,
                        onDelete: () => _deleteItem(item),
                        onSetTarget: () async {
                          if (!ref.read(isProProvider)) {
                            _showProSheet(context);
                            return;
                          }
                          final newTarget =
                              await _showSetTargetSheet(context, item);
                          if (newTarget != null) {
                            await ref
                                .read(watchlistRepositoryProvider)
                                .update(item.copyWith(
                                    targetPrice: newTarget < 0
                                        ? null
                                        : newTarget,
                                    // Reset alert so new target can fire again
                                    clearNotified: true));
                          }
                        },
                      );
                    },
                  ),
                );
              },
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: const BoxDecoration(
          color: Color(0xFF161820),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PRO FEATURE',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kursziel-Benachrichtigungen',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Lass dich automatisch benachrichtigen, wenn ein Asset dein Kursziel erreicht — auch wenn die App geschlossen ist.\n\nDiese Funktion ist Teil von FinTrack Pro. Bald verfügbar!',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Verstanden'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<double?> _showSetTargetSheet(
      BuildContext context, WatchlistItem item) {
    final ctrl = TextEditingController(
        text: item.targetPrice?.toStringAsFixed(2) ?? '');
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF161820),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zielkurs für ${item.symbol}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Erhalte eine Benachrichtigung wenn der Kurs diesen Wert erreicht.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[\d.,]')),
                ],
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.25), fontSize: 18),
                  prefixText: '€  ',
                  prefixStyle:
                      const TextStyle(color: Colors.white54, fontSize: 18),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (item.targetPrice != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, -1.0),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                              color: Colors.redAccent, width: 1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Entfernen'),
                      ),
                    ),
                  if (item.targetPrice != null) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final raw =
                            ctrl.text.trim().replaceAll(',', '.');
                        final val = double.tryParse(raw);
                        if (val != null && val > 0) {
                          Navigator.pop(context, val);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Column(
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Watchlist',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFFFFD700),
                            Color(0xFFFFA500),
                          ]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Kursziele & Push-Benachrichtigungen',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Colors.white70, size: 26),
                onPressed: onAdd,
                tooltip: 'Asset hinzufügen',
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Watchlist tile ────────────────────────────────────────────────────────────

class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({
    required this.item,
    required this.currentPrice,
    required this.isLoading,
    required this.onDelete,
    required this.onSetTarget,
  });

  final WatchlistItem item;
  final double? currentPrice;
  final bool isLoading;
  final VoidCallback onDelete;
  final VoidCallback onSetTarget;

  Color get _typeColor {
    switch (item.type) {
      case 'etf':
        return const Color(0xFF3F8ACB);
      case 'crypto':
        return const Color(0xFFC85A7B);
      default:
        return AppColors.darkPositive;
    }
  }

  String get _typeLabel {
    switch (item.type) {
      case 'etf':
        return 'ETF';
      case 'crypto':
        return 'Krypto';
      default:
        return 'Aktie';
    }
  }

  String _formatPrice(double p) {
    if (p >= 10000) return '${(p / 1000).toStringAsFixed(1)}k €';
    if (p >= 1) return '${p.toStringAsFixed(2)} €';
    return '${p.toStringAsFixed(4)} €';
  }

  @override
  Widget build(BuildContext context) {
    final target = item.targetPrice;
    final reached =
        target != null && currentPrice != null && currentPrice! >= target;
    final distancePct = (target != null && currentPrice != null && currentPrice! > 0)
        ? ((target - currentPrice!) / currentPrice!) * 100
        : null;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 24),
      ),
      child: GestureDetector(
        onTap: onSetTarget,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: reached
                  ? AppColors.darkPositive.withOpacity(0.4)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              // Symbol badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _typeColor.withOpacity(0.3)),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        item.symbol.split('.').first.length > 4
                            ? item.symbol.split('.').first.substring(0, 4)
                            : item.symbol.split('.').first,
                        style: TextStyle(
                          color: _typeColor,
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
              // Name + type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _typeLabel,
                            style: TextStyle(
                              color: _typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (target != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            reached ? Icons.notifications_active : Icons.notifications_none,
                            size: 13,
                            color: reached
                                ? AppColors.darkPositive
                                : Colors.white38,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Ziel: ${_formatPrice(target)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: reached
                                  ? AppColors.darkPositive
                                  : Colors.white38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Price + distance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white24,
                      ),
                    )
                  else if (currentPrice != null)
                    Text(
                      _formatPrice(currentPrice!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Text(
                      '—',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.25), fontSize: 14),
                    ),
                  if (distancePct != null && !reached) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${distancePct >= 0 ? '+' : ''}${distancePct.toStringAsFixed(1)}% bis Ziel',
                      style: TextStyle(
                        fontSize: 10,
                        color: distancePct >= 0
                            ? AppColors.darkPositive
                            : Colors.white38,
                      ),
                    ),
                  ],
                  if (reached) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.darkPositive.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Ziel erreicht',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkPositive,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined,
              size: 48, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 16),
          const Text(
            'Deine Watchlist ist leer',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tippe + um Aktien, ETFs oder Krypto\nhinzuzufügen und Kursziele zu setzen.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Add watchlist sheet ────────────────────────────────────────────────────────

class _AddWatchlistSheet extends StatefulWidget {
  const _AddWatchlistSheet();

  @override
  State<_AddWatchlistSheet> createState() => _AddWatchlistSheetState();
}

class _AddWatchlistSheetState extends State<_AddWatchlistSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  Timer? _debounce;

  List<YahooSearchResult> _stockResults = [];
  List<YahooSearchResult> _cryptoResults = [];
  bool _searching = false;

  // symbol (uppercase) → EUR price; null means not-yet-fetched
  final Map<String, double?> _prices = {};
  // crypto symbol → CoinGecko coin id (for batch price lookup)
  final Map<String, String> _geckoIds = {};

  // Selection
  String? _selectedSymbol;
  String? _selectedName;
  String? _selectedType; // "stock" | "etf" | "crypto"

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {
          _clearSelection();
          _stockResults = [];
          _cryptoResults = [];
          _prices.clear();
          _geckoIds.clear();
          _searchCtrl.clear();
        }));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _targetCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _clearSelection() {
    _selectedSymbol = null;
    _selectedName = null;
    _selectedType = null;
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _stockResults = [];
        _cryptoResults = [];
        _prices.clear();
        _geckoIds.clear();
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _runSearch(q.trim()),
    );
  }

  Future<void> _runSearch(String q) async {
    if (_tabs.index == 0) {
      final results = await PriceService.searchAssets(q);
      if (!mounted) return;
      setState(() {
        _stockResults = results;
        _searching = false;
      });
      // Fetch prices for top 8 results in parallel (non-blocking)
      _fetchStockPrices(results.take(8).toList());
    } else {
      final raw = await PriceService.searchCryptos(q);
      if (!mounted) return;
      // Keep gecko IDs so we can do a batch price lookup
      for (final c in raw) {
        _geckoIds[c.symbol.toUpperCase()] = c.id;
      }
      setState(() {
        _cryptoResults = raw
            .map((c) => YahooSearchResult(
                  symbol: c.symbol,
                  name: c.name,
                  type: 'Krypto',
                  exchange: '',
                ))
            .toList();
        _searching = false;
      });
      // Batch-fetch EUR prices from CoinGecko
      _fetchCryptoPrices(raw.take(20).map((c) => c.id).toList());
    }
  }

  Future<void> _fetchStockPrices(List<YahooSearchResult> results) async {
    await Future.wait(results.map((r) async {
      final result = await PriceService.fetchStockOrEtfPrice(
        r.symbol,
        isEtf: r.type == 'ETF',
      );
      if (!mounted || result == null) return;
      setState(() => _prices[r.symbol.toUpperCase()] = result.price);
    }));
  }

  Future<void> _fetchCryptoPrices(List<String> geckoIds) async {
    final priceMap = await PriceService.fetchCoinGeckoPrices(geckoIds);
    if (!mounted) return;
    // Reverse-map geckoId → symbol → price
    for (final entry in _geckoIds.entries) {
      final price = priceMap[entry.value];
      if (price != null) {
        setState(() => _prices[entry.key] = price);
      }
    }
  }

  void _selectAsset(String symbol, String name, String type) {
    setState(() {
      _selectedSymbol = symbol;
      _selectedName = name;
      _selectedType = type;
    });
  }

  void _confirm() {
    if (_selectedSymbol == null || _selectedName == null) return;
    final raw = _targetCtrl.text.trim().replaceAll(',', '.');
    final target = double.tryParse(raw);
    final item = WatchlistItem(
      id: '',
      symbol: _selectedSymbol!,
      name: _selectedName!,
      type: _selectedType!,
      targetPrice: (target != null && target > 0) ? target : null,
      addedAt: DateTime.now(),
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF0D0F14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Asset hinzufügen',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabs,
                labelColor: AppColors.darkPrimary,
                unselectedLabelColor: Colors.white38,
                indicatorColor: AppColors.darkPrimary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.white10,
                tabs: const [
                  Tab(text: 'Aktie / ETF'),
                  Tab(text: 'Krypto'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                style:
                    const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: _tabs.index == 0
                      ? 'Suche nach Aktie oder ETF…'
                      : 'Suche nach Kryptowährung…',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.25), fontSize: 15),
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.white38, size: 20),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white38),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Results
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ResultsList(
                    results: _stockResults,
                    selected: _selectedSymbol,
                    prices: _prices,
                    onSelect: (r) =>
                        _selectAsset(r.symbol, r.name, r.type == 'ETF' ? 'etf' : 'stock'),
                    emptyHint: 'Tippe einen Aktien- oder ETF-Namen ein',
                  ),
                  _ResultsList(
                    results: _cryptoResults,
                    selected: _selectedSymbol,
                    prices: _prices,
                    onSelect: (r) =>
                        _selectAsset(r.symbol, r.name, 'crypto'),
                    emptyHint: 'Tippe den Namen einer Kryptowährung ein',
                  ),
                ],
              ),
            ),
            // Target + confirm
            if (_selectedSymbol != null) ...[
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.darkPositive, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_selectedSymbol — $_selectedName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedSymbol != null) ...[
                          const SizedBox(width: 8),
                          _PriceTag(
                            price: _prices[_selectedSymbol!.toUpperCase()],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _targetCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]')),
                            ],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Zielkurs optional',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 15),
                              prefixText: '€  ',
                              prefixStyle: const TextStyle(
                                  color: Colors.white54, fontSize: 15),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 20),
                          ),
                          child: const Text('Hinzufügen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Search results list ───────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.results,
    required this.selected,
    required this.prices,
    required this.onSelect,
    required this.emptyHint,
  });

  final List<YahooSearchResult> results;
  final String? selected;
  final Map<String, double?> prices;
  final void Function(YahooSearchResult) onSelect;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          emptyHint,
          style: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final r = results[i];
        final isSelected = r.symbol == selected;
        final price = prices[r.symbol.toUpperCase()];
        return GestureDetector(
          onTap: () => onSelect(r),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.darkPrimary.withOpacity(0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.darkPrimary.withOpacity(0.5)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.symbol,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        r.name,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Live price tag
                _PriceTag(price: price),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.type,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle,
                      color: AppColors.darkPositive, size: 18),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Price tag ─────────────────────────────────────────────────────────────────
// Shows a formatted EUR price, or a small loading dots indicator if null.

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price});
  final double? price;

  String _fmt(double p) {
    if (p >= 10000) return '${(p / 1000).toStringAsFixed(1)}k €';
    if (p >= 1) return '${p.toStringAsFixed(2)} €';
    return '${p.toStringAsFixed(4)} €';
  }

  @override
  Widget build(BuildContext context) {
    if (price == null) {
      // Subtle loading indicator — three dots
      return Text(
        '···',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.2),
          fontSize: 12,
          letterSpacing: 2,
        ),
      );
    }
    return Text(
      _fmt(price!),
      style: TextStyle(
        color: AppColors.darkPositive.withValues(alpha: 0.9),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
