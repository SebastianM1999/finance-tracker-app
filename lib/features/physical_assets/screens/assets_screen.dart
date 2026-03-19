import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/services/price_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/physical_asset.dart';

class AssetsTabBody extends ConsumerStatefulWidget {
  const AssetsTabBody({super.key});

  @override
  ConsumerState<AssetsTabBody> createState() => _AssetsTabBodyState();
}

class _AssetsTabBodyState extends ConsumerState<AssetsTabBody> {
  bool _refreshing = false;

  static const _commodityTickers = {
    'Gold': 'GC=F',
    'Silber': 'SI=F',
    'Platin': 'PL=F',
  };

  Future<void> _refreshAll(List<PhysicalAsset> list) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final repo = ref.read(assetsRepositoryProvider);
    int updated = 0;
    for (final asset in list) {
      final ticker = _commodityTickers[asset.assetType];
      if (ticker == null) continue;
      final result = await PriceService.fetchCommodityPrice(ticker);
      if (result == null) continue;
      // quantity is stored in troy oz, result.price is per troy oz
      final double newValue = result.price * asset.quantity;
      await repo.update(PhysicalAsset(
        id: asset.id,
        assetType: asset.assetType,
        description: asset.description,
        quantity: asset.quantity,
        weightPerUnit: asset.weightPerUnit,
        buyPrice: asset.buyPrice,
        currentValue: newValue,
        notes: asset.notes,
        createdAt: asset.createdAt,
      ));
      updated++;
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$updated Asset(s) aktualisiert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(assetsStreamProvider);
    final total = ref.watch(assetsTotalProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: stream.when(
        loading: () => const ShimmerList(),
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
                        itemBuilder: (ctx, i) => _AssetCard(asset: list[i]),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Asset hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, [PhysicalAsset? asset]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssetSheet(asset: asset),
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
  final List<PhysicalAsset> list;

  @override
  Widget build(BuildContext context) {
    final totalBuy = list.fold(0.0, (s, a) => s + a.buyPrice);
    final pnl = total - totalBuy;
    final pnlPos = pnl >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradientPhysical,
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

class _AssetCard extends ConsumerWidget {
  const _AssetCard({required this.asset});
  final PhysicalAsset asset;

  static const _faIcons = {
    'Gold': FontAwesomeIcons.coins,
    'Silber': FontAwesomeIcons.coins,
    'Platin': FontAwesomeIcons.gem,
    'Immobilie': FontAwesomeIcons.houseChimney,
    'Auto': FontAwesomeIcons.car,
    'Öl': FontAwesomeIcons.oilCan,
    'Sonstiges': FontAwesomeIcons.gem,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pnlPos = asset.pnlAbsolute >= 0;

    return Dismissible(
      key: Key(asset.id),
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
        title: 'Asset löschen',
        message: '${asset.description} wirklich löschen?',
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(assetsRepositoryProvider).delete(asset.id);
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _AssetSheet(asset: asset),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppColors.gradientPhysical),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FaIcon(
                      _faIcons[asset.assetType] ?? FontAwesomeIcons.gem,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.description,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${asset.assetType}${asset.weightPerUnit != null ? ' · ${asset.weightPerUnit}g/Stk' : ''} · ${asset.quantity}x',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(asset.currentValue),
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
                          pnlPos
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 12,
                          color: pnlPos
                              ? AppColors.darkPositive
                              : AppColors.darkSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${CurrencyFormatter.formatPnl(asset.pnlAbsolute)} (${asset.pnlPercent.toStringAsFixed(1)}%)',
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
              gradient: const LinearGradient(
                  colors: AppColors.gradientPhysical),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.diamond_outlined,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Noch keine Assets',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Tippe auf + um ein Asset hinzuzufügen',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Add / Edit Sheet ──────────────────────────────────────────────────────────

class _AssetSheet extends ConsumerStatefulWidget {
  const _AssetSheet({this.asset});
  final PhysicalAsset? asset;

  @override
  ConsumerState<_AssetSheet> createState() => _AssetSheetState();
}

class _AssetSheetState extends ConsumerState<_AssetSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _description;
  late final TextEditingController _ozQty; // troy oz (metals, oz mode)
  late final TextEditingController _notes;

  double _buyPrice = 0;
  double _currentValue = 0;
  String _assetType = 'Gold';
  bool _saving = false;

  // EUR mode (metals)
  bool _useEurMode = true;
  double _eurAmount = 0;
  double _spotPrice = 0;
  bool _fetchingPrice = false;

  static const _types = ['Gold', 'Silber', 'Platin', 'Immobilie', 'Auto', 'Sonstiges'];
  static const _metalTickers = {'Gold': 'GC=F', 'Silber': 'SI=F', 'Platin': 'PL=F'};

  bool get _isEdit => widget.asset != null;
  bool get _isMetal => _metalTickers.containsKey(_assetType);

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    _description = TextEditingController(text: a?.description ?? '');
    // For edit mode show existing oz quantity
    _ozQty = TextEditingController(
        text: a != null ? a.quantity.toStringAsFixed(4) : '');
    _notes = TextEditingController(text: a?.notes ?? '');
    _buyPrice = a?.buyPrice ?? 0;
    _currentValue = a?.currentValue ?? 0;
    _assetType = a?.assetType ?? 'Gold';
    // Edit mode: default to oz mode so the user sees stored values
    _useEurMode = !_isEdit;

    if (_isMetal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSpotPrice());
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _ozQty.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _fetchSpotPrice() async {
    final ticker = _metalTickers[_assetType];
    if (ticker == null) return;
    setState(() => _fetchingPrice = true);
    final result = await PriceService.fetchCommodityPrice(ticker);
    if (!mounted) return;
    setState(() {
      _fetchingPrice = false;
      if (result != null) _spotPrice = result.price;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(assetsRepositoryProvider);
      final now = DateTime.now();

      double qty;
      double buyPriceTotal;
      double currentVal;

      if (_isMetal) {
        if (_useEurMode) {
          final price = _spotPrice > 0 ? _spotPrice : 1.0;
          qty = _eurAmount / price;
          buyPriceTotal = _eurAmount;
          currentVal = _eurAmount;
        } else {
          qty = double.tryParse(_ozQty.text.trim().replaceAll(',', '.')) ?? 1.0;
          buyPriceTotal = _buyPrice;
          currentVal = _spotPrice > 0 ? _spotPrice * qty : _currentValue;
        }
      } else {
        qty = 1.0;
        buyPriceTotal = _buyPrice;
        currentVal = _currentValue > 0 ? _currentValue : _buyPrice;
      }

      final a = PhysicalAsset(
        id: widget.asset?.id ?? '',
        assetType: _assetType,
        description: _description.text.trim(),
        quantity: qty,
        weightPerUnit: null,
        buyPrice: buyPriceTotal,
        currentValue: currentVal > 0 ? currentVal : buyPriceTotal,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: widget.asset?.createdAt ?? now,
      );
      if (_isEdit) {
        await repo.update(a);
      } else {
        await repo.add(a);
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
                _isEdit ? 'Asset bearbeiten' : 'Asset hinzufügen',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Type dropdown
              DropdownButtonFormField<String>(
                value: _assetType,
                decoration: const InputDecoration(labelText: 'Typ'),
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _assetType = v ?? _assetType;
                    _spotPrice = 0;
                    _useEurMode = !_isEdit;
                  });
                  if (_isMetal) _fetchSpotPrice();
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                    labelText: 'Bezeichnung (z.B. Krugerrand)'),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),

              // ── Metal inputs ───────────────────────────────────────────────
              if (_isMetal) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('€ Betrag')),
                    ButtonSegment(value: false, label: Text('Unzen (oz)')),
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
                  const SizedBox(height: 6),
                  if (_fetchingPrice)
                    Text('Live-Preis wird geladen...',
                        style: theme.textTheme.bodyMedium)
                  else if (_spotPrice > 0 && _eurAmount > 0)
                    Text(
                      '≈ ${(_eurAmount / _spotPrice).toStringAsFixed(4)} oz  ·  Kurs: ${CurrencyFormatter.format(_spotPrice)}/oz',
                      style: theme.textTheme.bodyMedium,
                    )
                  else if (_spotPrice > 0)
                    Text(
                      'Aktueller Kurs: ${CurrencyFormatter.format(_spotPrice)}/oz',
                      style: theme.textTheme.bodyMedium,
                    ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ozQty,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Menge', suffixText: 'oz'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                            if (double.tryParse(v.trim().replaceAll(',', '.')) == null) return 'Ungültig';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CurrencyInputField(
                          label: 'Kaufpreis gesamt',
                          initialValue: _buyPrice > 0 ? _buyPrice : null,
                          onChanged: (v) => setState(() => _buyPrice = v),
                        ),
                      ),
                    ],
                  ),
                  if (_spotPrice > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Aktueller Kurs: ${CurrencyFormatter.format(_spotPrice)}/oz',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ]
              // ── Non-metal inputs ───────────────────────────────────────────
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: CurrencyInputField(
                        label: 'Kaufpreis',
                        initialValue: _buyPrice > 0 ? _buyPrice : null,
                        onChanged: (v) => setState(() => _buyPrice = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CurrencyInputField(
                        label: 'Aktueller Wert',
                        initialValue: _currentValue > 0 ? _currentValue : null,
                        onChanged: (v) => setState(() => _currentValue = v),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration:
                    const InputDecoration(labelText: 'Notizen (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
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
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isEdit ? 'Speichern' : 'Hinzufügen',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
