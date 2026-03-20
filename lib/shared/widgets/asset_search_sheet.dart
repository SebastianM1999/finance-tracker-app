import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../data/known_assets.dart';
import '../services/price_service.dart';

// ── Crypto Search ─────────────────────────────────────────────────────────────

Future<KnownCrypto?> showCryptoSearchSheet(BuildContext context) {
  return showModalBottomSheet<KnownCrypto>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CryptoSearchSheet(),
  );
}

class _CryptoSearchSheet extends StatefulWidget {
  const _CryptoSearchSheet();

  @override
  State<_CryptoSearchSheet> createState() => _CryptoSearchSheetState();
}

class _CryptoSearchSheetState extends State<_CryptoSearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  List<KnownCrypto> get _filtered {
    if (_query.isEmpty) return KnownAssets.cryptos;
    final words = _query.toLowerCase().split(RegExp(r'\s+'));
    return KnownAssets.cryptos.where((c) {
      final haystack = '${c.name} ${c.symbol}'.toLowerCase();
      return words.every((w) => haystack.contains(w));
    }).toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SearchSheetScaffold(
      title: 'Coin auswählen',
      searchCtrl: _ctrl,
      onSearch: (v) => setState(() => _query = v),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) {
        final a = _filtered[i];
        return _AssetTile(
          leading: _SymbolBadge(
            label: a.symbol,
            gradient: AppColors.gradientCrypto,
          ),
          title: a.name,
          subtitle: a.symbol,
          trailing: null,
          onTap: () => Navigator.pop(ctx, a),
        );
      },
    );
  }
}

// ── ETF / Stock Search ────────────────────────────────────────────────────────

Future<KnownEtf?> showEtfSearchSheet(BuildContext context) {
  return showModalBottomSheet<KnownEtf>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _EtfSearchSheet(),
  );
}

class _EtfSearchSheet extends StatefulWidget {
  const _EtfSearchSheet();

  @override
  State<_EtfSearchSheet> createState() => _EtfSearchSheetState();
}

class _EtfSearchSheetState extends State<_EtfSearchSheet> {
  static String _savedQuery = '';

  late final TextEditingController _ctrl;
  Timer? _debounce;
  String _query = '';
  List<YahooSearchResult> _results = [];
  bool _loading = false;
  // Web: batch-fetched prices (ticker → EUR price)
  Map<String, double> _webPrices = {};
  bool _pricesLoading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _savedQuery);
    _query = _savedQuery;
    if (_savedQuery.isNotEmpty) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch(_savedQuery));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _savedQuery = v.trim();
    setState(() => _query = v.trim());
    if (v.trim().isEmpty) {
      setState(() { _results = []; _loading = false; _webPrices = {}; });
      return;
    }
    setState(() { _loading = true; _webPrices = {}; });
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(v.trim()));
  }

  Future<void> _runSearch(String q) async {
    final local = _localFallback(q);
    final yahoo = await PriceService.searchAssets(q);
    final localSymbols = local.map((e) => e.symbol.toUpperCase()).toSet();
    final extra = yahoo.where((e) => !localSymbols.contains(e.symbol.toUpperCase())).toList();
    final combined = [...local, ...extra];
    if (!mounted) return;
    setState(() { _results = combined; _loading = false; });

    // On web, fetch all prices in one batch request instead of individually
    if (kIsWeb && combined.isNotEmpty) {
      if (mounted) setState(() => _pricesLoading = true);
      final tickerMap = {for (final r in combined) r.symbol: r.type == 'ETF'};
      final prices = await PriceService.fetchBatchPrices(tickerMap);
      if (mounted) setState(() { _webPrices = prices; _pricesLoading = false; });
    }
  }

  /// Fuzzy-match against the static known list.
  /// Any word in the query just needs to appear somewhere in name/ticker.
  List<YahooSearchResult> _localFallback(String query) {
    final words = query.toLowerCase()
        .replaceAll(RegExp(r'[-_]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return KnownAssets.etfsAndStocks
        .where((e) {
          final hay = '${e.name} ${e.ticker} ${e.exchange}'
              .toLowerCase()
              .replaceAll(RegExp(r'[-_]'), ' ');
          return words.every((w) => hay.contains(w));
        })
        .map((e) => YahooSearchResult(
              symbol: e.ticker,
              name: e.name,
              type: e.type,
              exchange: e.exchange,
            ))
        .toList();
  }

  int get _itemCount {
    if (_query.isEmpty || _loading || _results.isEmpty) return 1;
    return _results.length;
  }

  @override
  Widget build(BuildContext context) {
    return _SearchSheetScaffold(
      title: 'ETF / Aktie suchen',
      searchCtrl: _ctrl,
      onSearch: _onSearch,
      itemCount: _itemCount,
      itemBuilder: (ctx, i) {
        if (_query.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('Tippe einen Namen oder Ticker ein...')),
          );
        }
        if (_loading) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_results.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('Keine Ergebnisse gefunden')),
          );
        }
        final r = _results[i];
        final isEtf = r.type == 'ETF';
        Widget? priceWidget;
        if (kIsWeb) {
          final p = _webPrices[r.symbol];
          if (_pricesLoading && p == null) {
            priceWidget = const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            );
          } else if (p != null) {
            priceWidget = Text(
              '${p.toStringAsFixed(2)}€',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkPositive,
                  ),
            );
          }
        } else {
          priceWidget = _LivePrice(ticker: r.symbol, isEtf: isEtf);
        }
        return _AssetTile(
          leading: _SymbolBadge(
            label: isEtf ? 'ETF' : '📈',
            gradient: isEtf ? AppColors.gradientEtf : AppColors.gradientPhysical,
          ),
          title: r.name,
          subtitle: r.symbol,
          trailing: priceWidget,
          onTap: () => Navigator.pop(
            ctx,
            KnownEtf(r.name, r.symbol, r.type, r.exchange),
          ),
        );
      },
    );
  }
}

// ── Live price widget ─────────────────────────────────────────────────────────

class _LivePrice extends StatefulWidget {
  const _LivePrice({required this.ticker, required this.isEtf});
  final String ticker;
  final bool isEtf;

  @override
  State<_LivePrice> createState() => _LivePriceState();
}

class _LivePriceState extends State<_LivePrice> {
  double? _price;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final result = await PriceService.fetchStockOrEtfPrice(
      widget.ticker,
      isEtf: widget.isEtf,
    );
    if (mounted) setState(() { _price = result?.price; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    if (_price == null) return const SizedBox.shrink();
    return Text(
      '${_price!.toStringAsFixed(2)}€',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.darkPositive,
          ),
    );
  }
}

// ── Shared: selected asset display widget ─────────────────────────────────────

/// Shows a tappable row with the currently selected asset (or "Auswählen" hint).
class AssetPickerRow extends StatelessWidget {
  const AssetPickerRow({
    super.key,
    required this.label,
    this.selectedName,
    this.selectedTag,
    required this.gradient,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String? selectedName;
  final String? selectedTag;
  final List<Color> gradient;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  bool get _hasSelection => selectedName != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasSelection
                ? gradient.first.withValues(alpha: 0.5)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            if (_hasSelection) ...[
              _SymbolBadge(label: selectedTag!, gradient: gradient),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selectedName!,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close,
                      size: 18, color: theme.colorScheme.outline),
                ),
            ] else ...[
              Icon(Icons.search, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.45)),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.outline, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _SearchSheetScaffold extends StatelessWidget {
  const _SearchSheetScaffold({
    required this.title,
    required this.searchCtrl,
    required this.onSearch,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String title;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Suchen...',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: onSearch,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SymbolBadge extends StatelessWidget {
  const _SymbolBadge({required this.label, required this.gradient});
  final String label;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final display = label.length > 4 ? label.substring(0, 4) : label;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        display,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

