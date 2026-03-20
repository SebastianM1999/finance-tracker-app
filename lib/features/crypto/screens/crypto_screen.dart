import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/data/known_assets.dart';
import '../../../shared/services/price_service.dart';
import '../../../shared/widgets/asset_search_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/crypto_position.dart';

class CryptoTabBody extends ConsumerStatefulWidget {
  const CryptoTabBody({super.key});

  @override
  ConsumerState<CryptoTabBody> createState() => _CryptoTabBodyState();
}

class _CryptoTabBodyState extends ConsumerState<CryptoTabBody> {
  bool _refreshing = false;

  Future<void> _refreshAll(List<CryptoPosition> list) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final repo = ref.read(cryptoRepositoryProvider);
    int updated = 0;
    for (final pos in list) {
      final result = await PriceService.fetchCryptoPrice(
          pos.coinSymbol, pos.coinName);
      if (result != null) {
        await repo.update(CryptoPosition(
          id: pos.id,
          exchange: pos.exchange,
          coinName: pos.coinName,
          coinSymbol: pos.coinSymbol,
          amount: pos.amount,
          buyPrice: pos.buyPrice,
          currentPrice: result.price,
          notes: pos.notes,
          createdAt: pos.createdAt,
        ));
        updated++;
      }
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$updated von ${list.length} Kurse aktualisiert'),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(cryptoStreamProvider);
    final total = ref.watch(cryptoTotalProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: stream.when(
        loading: () => const ShimmerList(cardHeight: 100),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : Column(
                children: [
                  _TotalBanner(
                    total: total,
                    list: list,
                  ),
                  const _PullHint(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _refreshAll(list),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) =>
                            _CryptoCard(position: list[i]),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Coin hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, [CryptoPosition? position]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CryptoSheet(position: position),
    );
  }
}

// ── Pull Hint ─────────────────────────────────────────────────────────────────

class _PullHint extends StatelessWidget {
  const _PullHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.keyboard_arrow_down,
              size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: 3),
          Text(
            'Zum Aktualisieren runterziehen',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Total Banner ──────────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({
    required this.total,
    required this.list,
  });
  final double total;
  final List<CryptoPosition> list;

  @override
  Widget build(BuildContext context) {
    final totalBuy = list.fold(0.0, (s, p) => s + p.buyValue);
    final pnl = total - totalBuy;
    final pnlPos = pnl >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradientCrypto,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aktueller Wert',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                CurrencyFormatter.format(total),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Gesamt P&L',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                CurrencyFormatter.formatPnl(pnl),
                style: TextStyle(
                  color: pnlPos
                      ? const Color(0xFFB8F5D8)
                      : const Color(0xFFFFB3B3),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _CryptoCard extends ConsumerWidget {
  const _CryptoCard({required this.position});
  final CryptoPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pnlPos = position.pnlAbsolute >= 0;

    return Dismissible(
      key: Key(position.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.darkSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => showConfirmDialog(
        context,
        title: 'Coin löschen',
        message: '${position.coinName} wirklich löschen?',
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(cryptoRepositoryProvider).delete(position.id);
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _CryptoSheet(position: position),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _CryptoLogo(symbol: position.coinSymbol),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(position.coinName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${CurrencyFormatter.formatCryptoAmount(position.amount)} ${position.coinSymbol} · Ø ${CurrencyFormatter.format(position.buyPrice)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(position.currentValue),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkPositive,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pnlPos ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: pnlPos
                              ? AppColors.darkPositive
                              : AppColors.darkSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${CurrencyFormatter.formatPnl(position.pnlAbsolute)} (${position.pnlPercent.toStringAsFixed(1)}%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pnlPos
                                ? AppColors.darkPositive
                                : AppColors.darkSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (position.lastPriceUpdate != null)
                      Text(
                        DateFormatter.priceAge(position.lastPriceUpdate),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Crypto Logo ───────────────────────────────────────────────────────────────

class _CryptoLogo extends StatelessWidget {
  const _CryptoLogo({required this.symbol});
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final url =
        'https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/${symbol.toLowerCase()}.png';
    return CachedNetworkImage(
      imageUrl: url,
      width: 40,
      height: 40,
      imageBuilder: (_, img) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: img, fit: BoxFit.cover),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: AppColors.gradientCrypto),
        ),
        child: const Center(
          child: FaIcon(FontAwesomeIcons.coins, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: AppColors.gradientCrypto),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.currency_bitcoin,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Noch keine Coins',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Tippe auf + um einen Coin hinzuzufügen',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Add / Edit Sheet ──────────────────────────────────────────────────────────

class _CryptoSheet extends ConsumerStatefulWidget {
  const _CryptoSheet({this.position});
  final CryptoPosition? position;

  @override
  ConsumerState<_CryptoSheet> createState() => _CryptoSheetState();
}

class _CryptoSheetState extends ConsumerState<_CryptoSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _coinName;
  late final TextEditingController _coinSymbol;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  double _buyPrice = 0;
  double _currentPrice = 0;
  bool _saving = false;
  bool _fetchingPrice = false;

  KnownCrypto? _pickedAsset;
  bool _manualEntry = false;

  // Input mode toggle
  bool _useEurMode = false;
  double _eurAmount = 0;

  bool get _isEdit => widget.position != null;
  bool get _showPicker => !_isEdit && _pickedAsset == null && !_manualEntry;

  @override
  void initState() {
    super.initState();
    final p = widget.position;
    _coinName = TextEditingController(text: p?.coinName ?? '');
    _coinSymbol = TextEditingController(text: p?.coinSymbol ?? '');
    _amount = TextEditingController(
        text: p != null ? p.amount.toString() : '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _buyPrice = p?.buyPrice ?? 0;
    _currentPrice = p?.currentPrice ?? 0;
  }

  @override
  void dispose() {
    _coinName.dispose();
    _coinSymbol.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onAssetPicked(KnownCrypto asset) {
    setState(() {
      _pickedAsset = asset;
      _coinName.text = asset.name;
      _coinSymbol.text = asset.symbol;
      _fetchingPrice = true;
    });
    PriceService.fetchCryptoPrice(asset.symbol, asset.name).then((result) {
      if (!mounted) return;
      setState(() {
        _fetchingPrice = false;
        if (result != null) {
          _currentPrice = result.price;
          _buyPrice = result.price;
        }
      });
    });
  }

  void _clearPick() {
    setState(() {
      _pickedAsset = null;
      _coinName.clear();
      _coinSymbol.clear();
      _buyPrice = 0;
      _currentPrice = 0;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(cryptoRepositoryProvider);
      final amount = _useEurMode
          ? (_buyPrice > 0 ? _eurAmount / _buyPrice : 0.0)
          : (double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0.0);
      final now = DateTime.now();
      final p = CryptoPosition(
        id: widget.position?.id ?? '',
        exchange: widget.position?.exchange ?? '',
        coinName: _coinName.text.trim(),
        coinSymbol: _coinSymbol.text.trim().toUpperCase(),
        amount: amount,
        buyPrice: _buyPrice,
        currentPrice: _currentPrice > 0 ? _currentPrice : _buyPrice,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: widget.position?.createdAt ?? now,
      );
      if (_isEdit) {
        await repo.update(p);
      } else {
        // Auto-merge if a position with the same symbol already exists
        final existing = ref.read(cryptoStreamProvider).valueOrNull ?? [];
        final match = existing.where((e) =>
            e.coinSymbol.toUpperCase() == p.coinSymbol.toUpperCase()).firstOrNull;
        if (match != null) {
          final totalAmount = match.amount + p.amount;
          final avgBuy = totalAmount > 0
              ? (match.amount * match.buyPrice + p.amount * p.buyPrice) / totalAmount
              : p.buyPrice;
          await repo.update(CryptoPosition(
            id: match.id,
            exchange: match.exchange,
            coinName: match.coinName,
            coinSymbol: match.coinSymbol,
            amount: totalAmount,
            buyPrice: avgBuy,
            currentPrice: p.currentPrice,
            notes: match.notes,
            createdAt: match.createdAt,
          ));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Mit bestehender ${match.coinName}-Position zusammengeführt'),
            ));
          }
        } else {
          await repo.add(p);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final amount = _useEurMode && _buyPrice > 0
        ? _eurAmount / _buyPrice
        : (double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0);
    final previewValue =
        amount > 0 && _currentPrice > 0 ? amount * _currentPrice : null;
    final previewPnl = previewValue != null && _buyPrice > 0
        ? previewValue - (amount * _buyPrice)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 20),
              Text(
                _isEdit ? 'Coin bearbeiten' : 'Coin hinzufügen',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // ── Asset Picker (always shown) ───────────────────────────────
              AssetPickerRow(
                label: _isEdit ? 'Coin neu zuordnen (optional)' : 'Coin auswählen...',
                selectedName: _pickedAsset?.name,
                selectedTag: _pickedAsset?.symbol,
                gradient: AppColors.gradientCrypto,
                onTap: () async {
                  final picked = await showCryptoSearchSheet(context);
                  if (picked != null) _onAssetPicked(picked);
                },
                onClear: _pickedAsset != null ? _clearPick : null,
              ),
              const SizedBox(height: 6),
              if (_showPicker)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _manualEntry = true),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Manuell eingeben',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 4),

              // ── Name + Symbol (edit / manual mode) ───────────────────────
              if (_isEdit || _manualEntry) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _coinName,
                        decoration: const InputDecoration(
                            labelText: 'Coin Name (z.B. Bitcoin)'),
                        validator: (v) =>
                            v?.trim().isEmpty == true
                                ? 'Pflichtfeld'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _coinSymbol,
                        decoration:
                            const InputDecoration(labelText: 'Symbol'),
                        validator: (v) =>
                            v?.trim().isEmpty == true
                                ? 'Pflichtfeld'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Hidden validators for picker mode
              if (!_isEdit && _pickedAsset != null) ...[
                Offstage(
                  child: TextFormField(
                    controller: _coinName,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                  ),
                ),
                Offstage(
                  child: TextFormField(
                    controller: _coinSymbol,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                  ),
                ),
              ],

              // ── Rest of form (once asset chosen) ─────────────────────────
              if (_isEdit || _manualEntry || _pickedAsset != null) ...[
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Menge (Coins)')),
                    ButtonSegment(value: true, label: Text('€ Betrag')),
                  ],
                  selected: {_useEurMode},
                  onSelectionChanged: (s) =>
                      setState(() => _useEurMode = s.first),
                ),
                const SizedBox(height: 12),
                if (_useEurMode) ...[
                  CurrencyInputField(
                    label: 'Investierter Betrag',
                    initialValue: _eurAmount > 0 ? _eurAmount : null,
                    onChanged: (v) => setState(() => _eurAmount = v),
                  ),
                  if (_buyPrice > 0 && _eurAmount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '≈ ${CurrencyFormatter.formatCryptoAmount(_eurAmount / _buyPrice)} Coins',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ] else ...[
                  TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(labelText: 'Menge'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                      final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
                      if (parsed == null) return 'Ungültig';
                      if (parsed <= 0) return 'Menge muss größer als 0 sein';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),

                // Price fields with loading state
                if (_fetchingPrice)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Live-Preis wird geladen...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: CurrencyInputField(
                          label: 'Kaufkurs',
                          initialValue: _buyPrice,
                          onChanged: (v) =>
                              setState(() => _buyPrice = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CurrencyInputField(
                          label: 'Aktueller Kurs',
                          initialValue: _currentPrice,
                          onChanged: (v) =>
                              setState(() => _currentPrice = v),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),

                if (previewValue != null && !_fetchingPrice) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: AppColors.gradientCrypto),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Aktueller Wert',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(
                              CurrencyFormatter.format(previewValue),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        if (previewPnl != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('P&L',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12)),
                              Text(
                                CurrencyFormatter.formatPnl(previewPnl),
                                style: TextStyle(
                                  color: previewPnl >= 0
                                      ? const Color(0xFFB8F5D8)
                                      : const Color(0xFFFFB3B3),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                      labelText: 'Notizen (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_saving || _fetchingPrice) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : Text(
                            _isEdit ? 'Speichern' : 'Hinzufügen',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
