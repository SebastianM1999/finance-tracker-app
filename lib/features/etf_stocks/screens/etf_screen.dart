import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/data/known_assets.dart';
import '../../../shared/services/price_service.dart';
import '../../../shared/widgets/asset_search_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/etf_position.dart';

class EtfTabBody extends ConsumerStatefulWidget {
  const EtfTabBody({super.key});

  @override
  ConsumerState<EtfTabBody> createState() => _EtfTabBodyState();
}

class _EtfTabBodyState extends ConsumerState<EtfTabBody> {
  bool _refreshing = false;

  Future<void> _refreshAll(List<EtfPosition> list) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final repo = ref.read(etfRepositoryProvider);
    int updated = 0;
    for (final pos in list) {
      if (pos.ticker == null) continue;
      final result = await PriceService.fetchStockOrEtfPrice(
        pos.ticker!,
        isEtf: pos.assetType == 'ETF',
      );
      if (result != null) {
        await repo.update(EtfPosition(
          id: pos.id,
          broker: pos.broker,
          name: pos.name,
          ticker: pos.ticker,
          shares: pos.shares,
          buyPrice: pos.buyPrice,
          currentPrice: result.price,
          currency: pos.currency,
          assetType: pos.assetType,
          lastPriceUpdate: DateTime.now(),
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
    final stream = ref.watch(etfStreamProvider);
    final total = ref.watch(etfTotalProvider);

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
                            _EtfCard(position: list[i]),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Position hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, [EtfPosition? position]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EtfSheet(position: position),
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
  final List<EtfPosition> list;

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
          colors: AppColors.gradientEtf,
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

class _EtfCard extends ConsumerWidget {
  const _EtfCard({required this.position});
  final EtfPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pnlPos = position.pnlAbsolute >= 0;
    final gradient = position.assetType == 'ETF'
        ? AppColors.gradientEtf
        : AppColors.gradientPhysical;
    final tickerDisplay = position.ticker ??
        (position.name.length < 4
            ? position.name
            : position.name.substring(0, 4))
            .toUpperCase();

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
        title: 'Position löschen',
        message: '${position.name} wirklich löschen?',
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(etfRepositoryProvider).delete(position.id);
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _EtfSheet(position: position),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _TickerBadge(ticker: tickerDisplay, gradient: gradient),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(position.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (position.ticker != null)
                        Text(
                          position.ticker!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      Text(
                        '${position.shares} Anteile · Ø ${CurrencyFormatter.format(position.buyPrice)}',
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
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

// ── Ticker Badge ──────────────────────────────────────────────────────────────

class _TickerBadge extends StatelessWidget {
  const _TickerBadge({required this.ticker, required this.gradient});
  final String ticker;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final display = ticker.length > 5 ? ticker.substring(0, 5) : ticker;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          display,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
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
              gradient: const LinearGradient(colors: AppColors.gradientEtf),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.trending_up,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Noch keine Positionen',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Tippe auf + um eine Position hinzuzufügen',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Add / Edit Sheet ──────────────────────────────────────────────────────────

class _EtfSheet extends ConsumerStatefulWidget {
  const _EtfSheet({this.position});
  final EtfPosition? position;

  @override
  ConsumerState<_EtfSheet> createState() => _EtfSheetState();
}

class _EtfSheetState extends ConsumerState<_EtfSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _ticker;
  late final TextEditingController _shares;
  late final TextEditingController _notes;

  double _buyPrice = 0;
  double _currentPrice = 0;
  String _assetType = 'ETF';
  bool _saving = false;
  bool _fetchingPrice = false;

  // Picker state — only used in add mode
  KnownEtf? _pickedAsset;
  bool _manualEntry = false;

  // Input mode toggle
  bool _useEurMode = false;
  double _eurAmount = 0;

  bool get _isEdit => widget.position != null;

  bool get _showPicker =>
      !_isEdit && _pickedAsset == null && !_manualEntry;

  @override
  void initState() {
    super.initState();
    final p = widget.position;
    _name = TextEditingController(text: p?.name ?? '');
    _ticker = TextEditingController(text: p?.ticker ?? '');
    _shares = TextEditingController(
        text: p != null ? p.shares.toString() : '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _buyPrice = p?.buyPrice ?? 0;
    _currentPrice = p?.currentPrice ?? 0;
    _assetType = p?.assetType ?? 'ETF';
  }

  @override
  void dispose() {
    _name.dispose();
    _ticker.dispose();
    _shares.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onAssetPicked(KnownEtf asset) {
    setState(() {
      _pickedAsset = asset;
      _name.text = asset.name;
      _ticker.text = asset.ticker;
      _assetType = asset.type == 'Aktie' ? 'Stock' : 'ETF';
      _fetchingPrice = true;
    });
    PriceService.fetchStockOrEtfPrice(
      asset.ticker,
      isEtf: asset.type == 'ETF',
    ).then((result) {
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
      _name.clear();
      _ticker.clear();
      _assetType = 'ETF';
      _buyPrice = 0;
      _currentPrice = 0;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(etfRepositoryProvider);
      final shares = _useEurMode
          ? (_buyPrice > 0 ? _eurAmount / _buyPrice : 0.0)
          : (double.tryParse(_shares.text.trim().replaceAll(',', '.')) ?? 0.0);
      final now = DateTime.now();
      final p = EtfPosition(
        id: widget.position?.id ?? '',
        broker: widget.position?.broker ?? '',
        name: _name.text.trim(),
        ticker: _ticker.text.trim().isEmpty ? null : _ticker.text.trim(),
        shares: shares,
        buyPrice: _buyPrice,
        currentPrice: _currentPrice > 0 ? _currentPrice : _buyPrice,
        assetType: _assetType,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: widget.position?.createdAt ?? now,
      );
      if (_isEdit) {
        await repo.update(p);
      } else {
        // Auto-merge if a position with the same ticker (or name) already exists
        final existing = ref.read(etfStreamProvider).valueOrNull ?? [];
        final match = existing.where((e) {
          if (p.ticker != null && e.ticker != null) {
            return e.ticker!.toUpperCase() == p.ticker!.toUpperCase();
          }
          return e.name.toUpperCase() == p.name.toUpperCase();
        }).firstOrNull;
        if (match != null) {
          final totalShares = match.shares + p.shares;
          final avgBuy = totalShares > 0
              ? (match.shares * match.buyPrice + p.shares * p.buyPrice) / totalShares
              : p.buyPrice;
          await repo.update(EtfPosition(
            id: match.id,
            broker: match.broker,
            name: match.name,
            ticker: match.ticker,
            shares: totalShares,
            buyPrice: avgBuy,
            currentPrice: p.currentPrice,
            assetType: match.assetType,
            notes: match.notes,
            createdAt: match.createdAt,
          ));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Mit bestehender ${match.name}-Position zusammengeführt'),
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

    final shares = _useEurMode && _buyPrice > 0
        ? _eurAmount / _buyPrice
        : (double.tryParse(_shares.text.replaceAll(',', '.')) ?? 0);
    final previewValue =
        shares > 0 && _currentPrice > 0 ? shares * _currentPrice : null;
    final previewPnl = previewValue != null && _buyPrice > 0
        ? previewValue - (shares * _buyPrice)
        : null;

    final gradient = _assetType == 'ETF'
        ? AppColors.gradientEtf
        : AppColors.gradientPhysical;

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
                _isEdit ? 'Position bearbeiten' : 'Position hinzufügen',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // ── Asset Picker (always shown) ───────────────────────────────
              AssetPickerRow(
                label: _isEdit ? 'Asset neu zuordnen (optional)' : 'ETF / Aktie auswählen...',
                selectedName: _pickedAsset?.name,
                selectedTag: _pickedAsset != null
                    ? (_pickedAsset!.type == 'ETF' ? 'ETF' : '📈')
                    : null,
                gradient: gradient,
                onTap: () async {
                  final picked = await showEtfSearchSheet(context);
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

              // ── Asset type toggle + Name + Ticker (edit / manual) ─────────
              if (_isEdit || _manualEntry) ...[
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'ETF', label: Text('ETF')),
                    ButtonSegment(value: 'Stock', label: Text('Aktie')),
                  ],
                  selected: {_assetType},
                  onSelectionChanged: (s) =>
                      setState(() => _assetType = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Name (z.B. MSCI World, Apple)'),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ticker,
                  decoration:
                      const InputDecoration(labelText: 'Ticker (optional)'),
                ),
              ],

              // Hidden validators for picker mode
              if (!_isEdit && _pickedAsset != null) ...[
                Offstage(
                  child: TextFormField(
                    controller: _name,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                  ),
                ),
              ],

              // ── Rest of form (once asset chosen) ──────────────────────────
              if (_isEdit || _manualEntry || _pickedAsset != null) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Anzahl Anteile')),
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
                      '≈ ${CurrencyFormatter.formatCryptoAmount(_eurAmount / _buyPrice)} Anteile',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ] else ...[
                  TextFormField(
                    controller: _shares,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Anzahl Anteile'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                      final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
                      if (parsed == null) return 'Ungültig';
                      if (parsed <= 0) return 'Anzahl muss größer als 0 sein';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),

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
                          onChanged: (v) => setState(() => _buyPrice = v),
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
                      gradient: LinearGradient(colors: gradient),
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
