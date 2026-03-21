import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_color.dart';
import '../../../shared/services/price_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/glow_icon.dart';
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
        lastPriceUpdate: DateTime.now(),
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
                  _TotalBanner(total: total, list: list)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, end: 0, duration: 400.ms),
                  const _PullHint(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _refreshAll(list),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _AssetCard(asset: list[i])
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: i.clamp(0, 4) * 55),
                              duration: 300.ms,
                            )
                            .slideX(
                              begin: 0.08,
                              end: 0,
                              delay: Duration(milliseconds: i.clamp(0, 4) * 55),
                              duration: 300.ms,
                            ),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aktueller Wert',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Gesamt P&L',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  CurrencyFormatter.formatPnl(pnl),
                  style: TextStyle(
                    color: pnlPos
                        ? const Color(0xFFB8F5D8)
                        : const Color(0xFFFFB3B3),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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

  static const _metalIconGradients = <String, List<Color>>{
    'Gold':   [Color(0xFFFFD700), Color(0xFFB8860B)],
    'Silber': [Color(0xFFD8D8D8), Color(0xFF909090)],
    'Platin': [Color(0xFFB0C4DE), Color(0xFF607080)],
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
                GlowIcon(
                  icon: _faIcons[asset.assetType] ?? FontAwesomeIcons.gem,
                  gradient: _metalIconGradients[asset.assetType] ??
                      IconColor.gradientFor(asset.id),
                  isFa: true,
                  size: 26,
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
                        '${asset.assetType}${asset.weightPerUnit != null ? ' · ${asset.weightPerUnit}g/Stk' : ''} · ${asset.quantity.toStringAsFixed(2)}x',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                      CurrencyFormatter.format(asset.currentValue),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkPositive,
                      ),
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
                        Flexible(
                          child: Text(
                          '${CurrencyFormatter.formatPnl(asset.pnlAbsolute)} (${asset.pnlPercent.toStringAsFixed(1)}%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pnlPos
                                ? AppColors.darkPositive
                                : AppColors.darkSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        ),  // Flexible
                      ],
                    ),
                    if (asset.lastPriceUpdate != null)
                      Text(
                        DateFormatter.priceAge(asset.lastPriceUpdate),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                  ],
                  ),
                ),  // ConstrainedBox
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
  double _buyPricePerOz = 0; // oz mode: buy price per troy oz
  double _currentValue = 0;
  String _assetType = 'Gold';
  bool _saving = false;

  // EUR mode (metals)
  bool _useEurMode = true;
  double _eurAmount = 0;     // current value in EUR (used to derive oz count)
  double _eurKaufbetrag = 0; // what the user originally paid
  double _spotPrice = 0;
  bool _fetchingPrice = false;

  static const _types = ['Gold', 'Silber', 'Platin', 'Immobilie', 'Auto', 'Öl', 'Sonstiges'];
  static const _metalTickers = {'Gold': 'GC=F', 'Silber': 'SI=F', 'Platin': 'PL=F'};

  bool get _isEdit => widget.asset != null;
  bool get _isMetal => _metalTickers.containsKey(_assetType);

  Color _buttonColor(ThemeData theme) {
    if (_isMetal && !_isEdit) {
      switch (_assetType) {
        case 'Gold':   return const Color(0xFFB8860B);
        case 'Silber': return const Color(0xFF909090);
        case 'Platin': return const Color(0xFF607080);
      }
    }
    return theme.colorScheme.primary;
  }

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
    _eurKaufbetrag = a?.buyPrice ?? 0;
    // In edit mode, derive per-oz price from total / quantity
    _buyPricePerOz = (a != null && a.quantity > 0) ? a.buyPrice / a.quantity : 0;
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
      if (result != null) {
        _spotPrice = result.price;
        if (_buyPricePerOz == 0) _buyPricePerOz = result.price;
        if (_eurAmount == 0) _eurAmount = result.price;
      }
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
          final kaufkurs = _buyPricePerOz > 0 ? _buyPricePerOz : (_spotPrice > 0 ? _spotPrice : 1.0);
          qty = _eurKaufbetrag > 0 ? _eurKaufbetrag / kaufkurs : 1.0;
          buyPriceTotal = _eurKaufbetrag > 0 ? _eurKaufbetrag : (_spotPrice * qty);
          currentVal = _spotPrice > 0 ? _spotPrice * qty : buyPriceTotal;
        } else {
          qty = double.tryParse(_ozQty.text.trim().replaceAll(',', '.')) ?? 1.0;
          buyPriceTotal = _buyPricePerOz > 0 ? _buyPricePerOz * qty : _buyPrice;
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
      if (!mounted) return;
      if (_isMetal) {
        // ignore: use_build_context_synchronously
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          builder: (_) => _MetalBarDialog(metalType: _assetType, isEdit: _isEdit),
        );
      } else if (_assetType == 'Auto') {
        // ignore: use_build_context_synchronously
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.80),
          builder: (_) => _CarCelebrationDialog(isEdit: _isEdit),
        );
      } else if (_assetType == 'Immobilie') {
        // ignore: use_build_context_synchronously
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          builder: (_) => _HouseCelebrationDialog(isEdit: _isEdit),
        );
      } else if (_assetType == 'Öl') {
        // ignore: use_build_context_synchronously
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          builder: (_) => _OilBarrelDialog(isEdit: _isEdit),
        );
      } else if (_assetType == 'Sonstiges') {
        // ignore: use_build_context_synchronously
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          builder: (_) => _SonstigesDialog(isEdit: _isEdit),
        );
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
                    _buyPricePerOz = 0;
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
                  Row(
                    children: [
                      Expanded(
                        child: CurrencyInputField(
                          label: 'Kaufbetrag (€)',
                          initialValue: _eurKaufbetrag > 0 ? _eurKaufbetrag : null,
                          onChanged: (v) => setState(() => _eurKaufbetrag = v),
                          loading: _fetchingPrice,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CurrencyInputField(
                          label: 'Kaufkurs/oz',
                          initialValue: _buyPricePerOz > 0 ? _buyPricePerOz : null,
                          onChanged: (v) => setState(() => _buyPricePerOz = v),
                          loading: _fetchingPrice,
                        ),
                      ),
                    ],
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
                          label: 'Kaufkurs/oz',
                          initialValue: _buyPricePerOz > 0 ? _buyPricePerOz : null,
                          onChanged: (v) => setState(() => _buyPricePerOz = v),
                          loading: _fetchingPrice,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // ── Price display (ETF-style) ───────────────────────────────
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
                else if (_spotPrice > 0) ...[
                  () {
                    final qty = _useEurMode
                        ? (_buyPricePerOz > 0 ? _eurKaufbetrag / _buyPricePerOz : 0)
                        : (double.tryParse(_ozQty.text.trim().replaceAll(',', '.')) ?? 0);
                    final currentVal = _spotPrice * qty;
                    final buy = _useEurMode
                        ? _eurKaufbetrag
                        : (_buyPricePerOz * qty);
                    final pnl = buy > 0 ? currentVal - buy : null;
                    final pnlPos = pnl == null || pnl >= 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Spot price row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Aktueller Kurs',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6))),
                              Text(
                                '${CurrencyFormatter.format(_spotPrice)}/oz',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        // Preview banner (only when amount/oz entered)
                        if (currentVal > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: AppColors.gradientPhysical),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Aktueller Wert',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    Text(
                                      CurrencyFormatter.format(currentVal),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_useEurMode && qty > 0)
                                      Text(
                                        '≈ ${qty.toStringAsFixed(4)} oz  ·  Kauf: ${CurrencyFormatter.format(_eurKaufbetrag)}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                ),
                                if (pnl != null && buy > 0)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('P&L',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          CurrencyFormatter.formatPnl(pnl),
                                          style: TextStyle(
                                            color: pnlPos
                                                ? const Color(0xFFB8F5D8)
                                                : const Color(0xFFFFB3B3),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${pnlPos ? '+' : ''}${(pnl / buy * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: pnlPos
                                              ? const Color(0xFFB8F5D8)
                                              : const Color(0xFFFFB3B3),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  }(),
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
                    backgroundColor: _buttonColor(theme),
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

// ── Metal Bar Celebration Dialog ──────────────────────────────────────────────

class _MetalBarDialog extends StatefulWidget {
  const _MetalBarDialog({required this.metalType, this.isEdit = false});
  final String metalType;
  final bool isEdit;

  @override
  State<_MetalBarDialog> createState() => _MetalBarDialogState();
}

class _MetalBarDialogState extends State<_MetalBarDialog> {
  static const _symbols = {'Gold': 'Au', 'Silber': 'Ag', 'Platin': 'Pt'};
  static const _labels  = {'Gold': 'GOLD', 'Silber': 'SILBER', 'Platin': 'PLATIN'};
  static const _gradients = <String, List<Color>>{
    'Gold':   [Color(0xFFFFE57F), Color(0xFFFFD700), Color(0xFF9A6A00)],
    'Silber': [Color(0xFFEEEEEE), Color(0xFFB8B8B8), Color(0xFF666666)],
    'Platin': [Color(0xFFD8E8F8), Color(0xFF9EB8CC), Color(0xFF3C5468)],
  };
  static const _glowColors = {
    'Gold':   Color(0xFFFFD700),
    'Silber': Color(0xFFBBBBBB),
    'Platin': Color(0xFF9EB8CC),
  };

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[widget.metalType] ?? _gradients['Gold']!;
    final glow   = _glowColors[widget.metalType] ?? const Color(0xFFFFD700);
    final symbol = _symbols[widget.metalType] ?? '';
    final label  = _labels[widget.metalType] ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MetalBarWidget(colors: colors, glow: glow, symbol: symbol, label: label)
              .animate()
              .scale(
                begin: const Offset(0.3, 0.3),
                end: const Offset(1.0, 1.0),
                duration: 550.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 250.ms)
              .then(delay: 100.ms)
              .shimmer(duration: 800.ms, color: Colors.white60),
          const SizedBox(height: 20),
          Text(
            '${widget.metalType} ${widget.isEdit ? 'aktualisiert' : 'hinzugefügt'}!',
            style: TextStyle(
              color: glow,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: glow.withValues(alpha: 0.6), blurRadius: 10)],
            ),
          )
              .animate()
              .fadeIn(delay: 350.ms, duration: 300.ms)
              .slideY(begin: 0.4, end: 0, delay: 350.ms, duration: 300.ms),
        ],
      ),
    );
  }
}

class _MetalBarWidget extends StatelessWidget {
  const _MetalBarWidget({
    required this.colors,
    required this.glow,
    required this.symbol,
    required this.label,
  });

  final List<Color> colors;
  final Color glow;
  final String symbol;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 130,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: glow.withValues(alpha: 0.55), blurRadius: 32, spreadRadius: 4),
          BoxShadow(color: glow.withValues(alpha: 0.25), blurRadius: 60, spreadRadius: 8),
        ],
      ),
      child: Stack(
        children: [
          // Top highlight stripe
          Positioned(
            top: 16, left: 18, right: 18,
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          // Bottom shadow stripe
          Positioned(
            bottom: 16, left: 18, right: 18,
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Chemical symbol + label
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  symbol,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(1, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          // Corner rivets
          Positioned(top: 8,    left: 8,   child: _Rivet()),
          Positioned(top: 8,    right: 8,  child: _Rivet()),
          Positioned(bottom: 8, left: 8,   child: _Rivet()),
          Positioned(bottom: 8, right: 8,  child: _Rivet()),
        ],
      ),
    );
  }
}

class _Rivet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2)],
      ),
    );
  }
}

// ── Car Celebration Dialog (Porsche) ──────────────────────────────────────────

class _CarCelebrationDialog extends StatefulWidget {
  const _CarCelebrationDialog({this.isEdit = false});
  final bool isEdit;

  @override
  State<_CarCelebrationDialog> createState() => _CarCelebrationDialogState();
}

class _CarCelebrationDialogState extends State<_CarCelebrationDialog>
    with TickerProviderStateMixin {
  late final AnimationController _driveCtrl;
  late final AnimationController _wheelCtrl;
  late final Animation<double> _carX;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _wheelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..repeat();
    _driveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          Navigator.of(context).pop();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_driveCtrl.isAnimating || _driveCtrl.isCompleted) return;
    final screenW = MediaQuery.of(context).size.width;
    const halfCarW = 90.0;

    _carX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -(screenW / 2 + halfCarW + 20), end: 0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 15),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: screenW / 2 + halfCarW + 20)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_driveCtrl);

    _textOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 28),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 20),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 22,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 18),
    ]).animate(_driveCtrl);

    _driveCtrl.forward();
  }

  @override
  void dispose() {
    _driveCtrl.dispose();
    _wheelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: screenW,
            height: 130,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Night sky
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0A0A1A), Color(0xFF1A1A2E)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Road surface
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 36,
                    color: const Color(0xFF2C2C2C),
                    child: CustomPaint(
                      painter: _RoadMarkingsPainter(),
                      size: Size(screenW, 36),
                    ),
                  ),
                ),
                // Yellow road edge line
                Positioned(
                  bottom: 35, left: 0, right: 0,
                  child: Container(height: 2, color: const Color(0xFFFFCC00)),
                ),
                // Car
                AnimatedBuilder(
                  animation: Listenable.merge([_driveCtrl, _wheelCtrl]),
                  builder: (_, __) => Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(_carX.value, -16),
                      child: _PorscheWidget(
                        wheelAngle: _wheelCtrl.value * 2 * pi,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _textOpacity,
            builder: (_, __) => Opacity(
              opacity: _textOpacity.value,
              child: Column(
                children: [
                  Text(
                    widget.isEdit ? 'Auto aktualisiert!' : 'Auto hinzugefügt!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vroom vroom',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Porsche Widget ────────────────────────────────────────────────────────────

class _PorscheWidget extends StatelessWidget {
  const _PorscheWidget({required this.wheelAngle});
  final double wheelAngle;

  static const _bodyTop     = Color(0xFFE8E8EC);
  static const _bodyBottom  = Color(0xFFB0B0B8);
  static const _cabinColor  = Color(0xFF1A1A28);
  static const _windowColor = Color(0xFF8EC6E8);
  static const _rimColor    = Color(0xFFCCCCCC);
  static const _headlight   = Color(0xFFFFEE88);
  static const _taillight   = Color(0xFFFF2222);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Body
          Positioned(
            left: 0, top: 30, width: 180, height: 36,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_bodyTop, _bodyBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
          ),
          // Front bumper / slope (right = front)
          Positioned(
            right: 0, top: 36, width: 22, height: 30,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD0D0D8), Color(0xFF909098)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
          ),
          // Cabin — very low and swept back
          Positioned(
            left: 42, top: 5, width: 90, height: 30,
            child: Container(
              decoration: const BoxDecoration(
                color: _cabinColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
          // Rear window
          Positioned(
            left: 47, top: 10, width: 38, height: 19,
            child: Container(
              decoration: BoxDecoration(
                color: _windowColor.withValues(alpha: 0.75),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
          // Front window (sloped)
          Positioned(
            left: 90, top: 10, width: 36, height: 19,
            child: Container(
              decoration: BoxDecoration(
                color: _windowColor.withValues(alpha: 0.75),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
          // Headlight
          Positioned(
            right: 7, top: 38,
            child: Container(
              width: 16, height: 9,
              decoration: BoxDecoration(
                color: _headlight,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: _headlight.withValues(alpha: 0.8),
                    blurRadius: 12,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          // Taillight
          Positioned(
            left: 4, top: 40,
            child: Container(
              width: 10, height: 7,
              decoration: BoxDecoration(
                color: _taillight,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: _taillight.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          // Porsche side stripe detail
          Positioned(
            left: 14, top: 44, right: 24,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          // Exhaust pipe
          Positioned(
            left: 7, top: 60,
            child: Container(
              width: 12, height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF555555),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Rear wheel
          Positioned(
            left: 20, top: 49,
            child: Transform.rotate(
              angle: wheelAngle,
              child: const SizedBox(
                width: 34, height: 34,
                child: CustomPaint(
                  painter: _WheelPainter(rimColor: _rimColor),
                ),
              ),
            ),
          ),
          // Front wheel
          Positioned(
            right: 20, top: 49,
            child: Transform.rotate(
              angle: wheelAngle,
              child: const SizedBox(
                width: 34, height: 34,
                child: CustomPaint(
                  painter: _WheelPainter(rimColor: _rimColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Road markings ─────────────────────────────────────────────────────────────

class _RoadMarkingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 3;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 24, size.height / 2),
        paint,
      );
      x += 48;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Wheel painter ─────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.rimColor});
  final Color rimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Tyre
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF111111));
    // Rim
    canvas.drawCircle(c, r * 0.60, Paint()..color = rimColor);
    // 5 spokes
    final spokePaint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5;
      canvas.drawLine(
        c + Offset(cos(a) * r * 0.14, sin(a) * r * 0.14),
        c + Offset(cos(a) * r * 0.56, sin(a) * r * 0.56),
        spokePaint,
      );
    }
    // Hub
    canvas.drawCircle(c, r * 0.17, Paint()..color = const Color(0xFF444444));
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.rimColor != rimColor;
}

// ── House Celebration Dialog (Immobilie) ──────────────────────────────────────

class _HouseCelebrationDialog extends StatefulWidget {
  const _HouseCelebrationDialog({this.isEdit = false});
  final bool isEdit;

  @override
  State<_HouseCelebrationDialog> createState() =>
      _HouseCelebrationDialogState();
}

class _HouseCelebrationDialogState extends State<_HouseCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Walls scale from bottom (0 → 1)
  late final Animation<double> _wallScale;
  // Roof drops from above (−70 → 0 px)
  late final Animation<double> _roofOffset;
  // Windows + door fade in (0 → 1)
  late final Animation<double> _details;
  // Celebration text (0 → 1)
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _wallScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 65),
    ]).animate(_ctrl);

    _roofOffset = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(-72), weight: 27),
      TweenSequenceItem(
        tween: Tween<double>(begin: -72, end: 0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 43),
    ]).animate(_ctrl);

    _details = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 55),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 27),
    ]).animate(_ctrl);

    _textOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 62),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 20),
    ]).animate(_ctrl);

    _ctrl
      ..forward()
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // House scene — ClipRect keeps the roof hidden while above
            ClipRect(
              child: SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _HousePainter(
                    wallScale: _wallScale.value,
                    roofOffset: _roofOffset.value,
                    detailOpacity: _details.value,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: _textOpacity.value,
              child: Column(
                children: [
                  Text(
                    widget.isEdit ? 'Immobilie aktualisiert!' : 'Immobilie hinzugefügt!',
                    style: const TextStyle(
                      color: Color(0xFFFFCC80),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Color(0x80FF8F00),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Herzlichen Glückwunsch!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── House Painter ─────────────────────────────────────────────────────────────

class _HousePainter extends CustomPainter {
  const _HousePainter({
    required this.wallScale,
    required this.roofOffset,
    required this.detailOpacity,
  });

  final double wallScale;
  final double roofOffset;
  final double detailOpacity;

  // Layout constants (for a 160×160 canvas)
  static const double _cx = 80;
  static const double _foundTop = 138;
  static const double _foundBot = 148;
  static const double _wallLeft = 22;
  static const double _wallRight = 138;
  static const double _wallTop = 76;   // walls go from here to _foundTop
  static const double _roofApexY = 22; // tip of the roof triangle
  static const double _chimneyL = 104;
  static const double _chimneyR = 118;
  static const double _chimneyTop = 36;

  @override
  void paint(Canvas canvas, Size size) {
    // ── Foundation ──────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromLTRBR(
          _wallLeft - 4, _foundTop, _wallRight + 4, _foundBot,
          const Radius.circular(3)),
      Paint()..color = const Color(0xFF90A4AE),
    );

    // ── Walls — scale Y from bottom ─────────────────────────────────────────
    final wallH = _foundTop - _wallTop;
    canvas.save();
    canvas.translate(_cx, _foundTop);
    canvas.scale(1.0, wallScale);
    canvas.translate(-_cx, -_foundTop);

    canvas.drawRRect(
      RRect.fromLTRBR(
          _wallLeft, _wallTop, _wallRight, _foundTop,
          const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF5E6C8), Color(0xFFE8D5A8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(
            _wallLeft, _wallTop, _wallRight - _wallLeft, wallH)),
    );

    canvas.restore();

    // ── Roof + chimney — translate from above ────────────────────────────────
    canvas.save();
    canvas.translate(0, roofOffset);

    // Chimney (behind roof so drawn first)
    canvas.drawRect(
      Rect.fromLTWH(_chimneyL, _chimneyTop, _chimneyR - _chimneyL,
          _wallTop - _chimneyTop + 4),
      Paint()..color = const Color(0xFF5D4037),
    );
    // Chimney cap
    canvas.drawRect(
      Rect.fromLTWH(_chimneyL - 3, _chimneyTop - 4,
          (_chimneyR - _chimneyL) + 6, 5),
      Paint()..color = const Color(0xFF4E342E),
    );

    // Roof triangle
    final roofPath = Path()
      ..moveTo(_wallLeft - 10, _wallTop)
      ..lineTo(_wallRight + 10, _wallTop)
      ..lineTo(_cx, _roofApexY)
      ..close();

    canvas.drawPath(
      roofPath,
      Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFF6D4C41), Color(0xFF4E342E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(
            _wallLeft - 10, _roofApexY, (_wallRight - _wallLeft) + 20,
            _wallTop - _roofApexY)),
    );

    // Roof ridge highlight
    canvas.drawLine(
      const Offset(_wallLeft - 10, _wallTop),
      const Offset(_wallRight + 10, _wallTop),
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();

    // ── Windows + door (fade in) ─────────────────────────────────────────────
    if (detailOpacity > 0) {
      final a = detailOpacity;

      // Left window
      _paintWindow(canvas, 32, _wallTop + 10, 26, 22, a);
      // Right window
      _paintWindow(canvas, _wallRight - 58, _wallTop + 10, 26, 22, a);
      // Door
      _paintDoor(canvas, _cx - 13, _foundTop - 36, 26, 36, a);
    }

    // ── Glow under foundation (ground shadow) ──────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(_cx, _foundBot + 4), width: 110, height: 10),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _paintWindow(Canvas canvas, double x, double y, double w, double h,
      double opacity) {
    // Glass
    canvas.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()
        ..color =
            const Color(0xFF81D4FA).withValues(alpha: opacity * 0.85),
    );
    // Reflection shimmer
    canvas.drawRect(
      Rect.fromLTWH(x + 2, y + 2, w * 0.35, h * 0.4),
      Paint()
        ..color =
            Colors.white.withValues(alpha: opacity * 0.45),
    );
    // Frame
    final frame = Paint()
      ..color =
          const Color(0xFF795548).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), frame);
    // Cross dividers
    canvas.drawLine(
        Offset(x + w / 2, y), Offset(x + w / 2, y + h), frame);
    canvas.drawLine(
        Offset(x, y + h / 2), Offset(x + w, y + h / 2), frame);
  }

  void _paintDoor(Canvas canvas, double x, double y, double w, double h,
      double opacity) {
    // Door body
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, w, h),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      ),
      Paint()
        ..color =
            const Color(0xFF6D4C41).withValues(alpha: opacity),
    );
    // Door panel detail
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 5, w - 8, (h / 2) - 6),
          const Radius.circular(2)),
      Paint()
        ..color = const Color(0xFF5D4037).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Doorknob
    canvas.drawCircle(
      Offset(x + w - 7, y + h * 0.58),
      3,
      Paint()
        ..color =
            const Color(0xFFFFD700).withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_HousePainter old) =>
      old.wallScale != wallScale ||
      old.roofOffset != roofOffset ||
      old.detailOpacity != detailOpacity;
}

// ── Oil Barrel Celebration Dialog (Öl) ────────────────────────────────────────

class _OilBarrelDialog extends StatefulWidget {
  const _OilBarrelDialog({this.isEdit = false});
  final bool isEdit;

  @override
  State<_OilBarrelDialog> createState() => _OilBarrelDialogState();
}

class _OilBarrelDialogState extends State<_OilBarrelDialog>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _tiltCtrl;
  late final AnimationController _dropCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _tilt;
  late final Animation<double> _dropY;
  late final Animation<double> _dropOpacity;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);

    _tiltCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _tilt = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.35).chain(CurveTween(curve: Curves.easeIn)),
        weight: 38,
      ),
      TweenSequenceItem(tween: ConstantTween(-0.35), weight: 15),
      TweenSequenceItem(
        tween: Tween(begin: -0.35, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 47,
      ),
    ]).animate(_tiltCtrl);

    _dropCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _dropY = Tween(begin: 0.0, end: 55.0)
        .animate(CurvedAnimation(parent: _dropCtrl, curve: Curves.easeIn));
    _dropOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_dropCtrl);

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _tiltCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 990), () {
      if (mounted) _dropCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _tiltCtrl.dispose();
    _dropCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labelColor = Color(0xFFFFB74D);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 130,
            height: 190,
            child: AnimatedBuilder(
              animation: Listenable.merge([_scaleCtrl, _tiltCtrl, _dropCtrl]),
              builder: (_, __) => Stack(
                alignment: Alignment.topCenter,
                children: [
                  Transform.scale(
                    scale: _scale.value,
                    child: Transform.rotate(
                      angle: _tilt.value,
                      child: const SizedBox(
                        width: 100,
                        height: 130,
                        child: CustomPaint(
                          painter: _BarrelPainter(),
                          size: Size(100, 130),
                        ),
                      ),
                    ),
                  ),
                  if (_dropCtrl.value > 0)
                    Positioned(
                      top: 18 + _dropY.value,
                      left: 13,
                      child: Opacity(
                        opacity: _dropOpacity.value,
                        child: Container(
                          width: 14,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5E00), Color(0xFF3E2600)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                              bottom: Radius.circular(7),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8C00).withValues(alpha: 0.35),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Text(
            widget.isEdit ? 'Öl aktualisiert!' : 'Öl hinzugefügt!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: labelColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Color(0x80FFB74D), blurRadius: 10)],
            ),
          )
              .animate()
              .fadeIn(delay: 420.ms, duration: 300.ms)
              .slideY(begin: 0.3, end: 0, delay: 420.ms, duration: 300.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BarrelPainter extends CustomPainter {
  const _BarrelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const left   = 20.0;
    const right  = 80.0;
    const top    = 14.0;
    const bottom = 118.0;
    const bW     = right - left;   // 60
    const bH     = bottom - top;   // 104

    // ── Body ────────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top, bW, bH), const Radius.circular(10)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(left, top, bW, bH)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top, 9, bH), const Radius.circular(10)),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    // ── Top ellipse ──────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(left, top - 7, bW, 18),
      Paint()..color = const Color(0xFF4E342E),
    );
    canvas.drawOval(
      Rect.fromLTWH(left + 6, top - 5, bW - 22, 12),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    // ── Bottom ellipse shadow ────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(left, bottom - 6, bW, 14),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // ── Metal hoops ──────────────────────────────────────────────────────────
    for (final hy in [38.0, 64.0, 90.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left - 2, hy, bW + 4, 9), const Radius.circular(3)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF4A4A4A), Color(0xFF1A1A1A)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(Rect.fromLTWH(left - 2, hy, bW + 4, 9)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left - 2, hy, bW + 4, 2), const Radius.circular(1)),
        Paint()..color = Colors.white.withValues(alpha: 0.12),
      );
    }

    // ── Oil-drop symbol ──────────────────────────────────────────────────────
    final dropSym = Path()
      ..moveTo(50, 58)
      ..cubicTo(56, 64, 57, 72, 50, 76)
      ..cubicTo(43, 72, 44, 64, 50, 58)
      ..close();
    canvas.drawPath(dropSym, Paint()..color = Colors.white.withValues(alpha: 0.22));
  }

  @override
  bool shouldRepaint(_BarrelPainter old) => false;
}

// ── Sonstiges Gem Celebration Dialog ─────────────────────────────────────────

class _SonstigesDialog extends StatefulWidget {
  const _SonstigesDialog({this.isEdit = false});
  final bool isEdit;

  @override
  State<_SonstigesDialog> createState() => _SonstigesDialogState();
}

class _SonstigesDialogState extends State<_SonstigesDialog>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _twinkleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _twinkleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _twinkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFCE93D8);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_scaleCtrl, _twinkleCtrl]),
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _GemPainter(twinkle: _twinkleCtrl.value),
                  size: const Size(110, 110),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.isEdit ? 'Asset aktualisiert!' : 'Asset hinzugefügt!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Color(0x80CE93D8), blurRadius: 10)],
            ),
          )
              .animate()
              .fadeIn(delay: 420.ms, duration: 300.ms)
              .slideY(begin: 0.3, end: 0, delay: 420.ms, duration: 300.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GemPainter extends CustomPainter {
  const _GemPainter({this.twinkle = 0.0});
  final double twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const tableR = 26.0;
    const tableY = 38.0;
    const pointY = 95.0;

    // 6 table edge points (hexagonal, perspective-flattened)
    final pts = List.generate(6, (i) {
      final a = i * pi / 3.0;
      return Offset(cx + cos(a) * tableR, tableY + sin(a) * tableR * 0.4);
    });

    final bottom = Offset(cx, pointY);

    // ── Facets ──────────────────────────────────────────────────────────────
    const facetColors = [
      Color(0xFFE040FB),
      Color(0xFF7C4DFF),
      Color(0xFF448AFF),
      Color(0xFF00E5FF),
      Color(0xFF69F0AE),
      Color(0xFFFFFF00),
    ];
    for (int i = 0; i < 6; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(pts[i].dx, pts[i].dy)
          ..lineTo(pts[(i + 1) % 6].dx, pts[(i + 1) % 6].dy)
          ..lineTo(bottom.dx, bottom.dy)
          ..close(),
        Paint()..color = facetColors[i].withValues(alpha: 0.90),
      );
    }

    // ── Table face ──────────────────────────────────────────────────────────
    final tablePath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < 6; i++) {
      tablePath.lineTo(pts[i].dx, pts[i].dy);
    }
    tablePath.close();
    canvas.drawPath(
      tablePath,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0xFFCE93D8)],
          center: Alignment(-0.25, -0.5),
          radius: 0.9,
        ).createShader(Rect.fromLTWH(cx - tableR, tableY - tableR * 0.4, tableR * 2, tableR * 0.8)),
    );

    // Facet division lines
    for (final p in pts) {
      canvas.drawLine(
        p, bottom,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..strokeWidth = 0.8,
      );
    }
    // Table outline
    canvas.drawPath(
      tablePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── Blinking sparkle dots (staggered) ───────────────────────────────────
    const sparklePts = [
      Offset(55, 5),
      Offset(100, 22),
      Offset(105, 66),
      Offset(10, 22),
      Offset(5, 66),
    ];
    for (int i = 0; i < sparklePts.length; i++) {
      // Each dot has a phase offset so they don't all blink in sync
      final phase = ((twinkle + i * 0.2) % 1.0);
      // Triangle wave: ramps 0→1 then 1→0 over the [0,1] range
      final brightness = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0;
      final r = 2.0 + brightness * 2.5;
      canvas.drawCircle(
        sparklePts[i], r,
        Paint()..color = Colors.white.withValues(alpha: 0.25 + brightness * 0.75),
      );
      canvas.drawCircle(
        sparklePts[i], r * 2.0,
        Paint()..color = Colors.white.withValues(alpha: brightness * 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_GemPainter old) => old.twinkle != twinkle;
}
