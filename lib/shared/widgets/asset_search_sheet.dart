import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../data/known_assets.dart';

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
  final _ctrl = TextEditingController();
  String _query = '';

  List<KnownEtf> get _filtered {
    if (_query.isEmpty) return KnownAssets.etfsAndStocks;
    final words = _query.toLowerCase().split(RegExp(r'\s+'));
    return KnownAssets.etfsAndStocks.where((e) {
      final haystack = '${e.name} ${e.ticker} ${e.exchange}'.toLowerCase();
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
      title: 'ETF / Aktie auswählen',
      searchCtrl: _ctrl,
      onSearch: (v) => setState(() => _query = v),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) {
        final a = _filtered[i];
        final isEtf = a.type == 'ETF';
        return _AssetTile(
          leading: _SymbolBadge(
            label: isEtf ? 'ETF' : '📈',
            gradient: isEtf ? AppColors.gradientEtf : AppColors.gradientPhysical,
          ),
          title: a.name,
          subtitle: a.ticker,
          trailing: _ExchangeChip(a.exchange),
          onTap: () => Navigator.pop(ctx, a),
        );
      },
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

class _ExchangeChip extends StatelessWidget {
  const _ExchangeChip(this.exchange);
  final String exchange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        exchange,
        style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500),
      ),
    );
  }
}
