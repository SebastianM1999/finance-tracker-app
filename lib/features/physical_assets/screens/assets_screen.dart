import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/physical_asset.dart';

class AssetsTabBody extends ConsumerWidget {
  const AssetsTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _TotalBanner(total: total, list: list),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(assetsStreamProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
        onPressed: () => _showSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Asset hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref,
      [PhysicalAsset? asset]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssetSheet(asset: asset),
    );
  }
}

// ── Total Banner ──────────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.total, required this.list});
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

  static const _icons = {
    'Gold': '🥇',
    'Silber': '🥈',
    'Immobilie': '🏠',
    'Auto': '🚗',
    'Sonstiges': '💎',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pnlPos = asset.pnlAbsolute >= 0;
    final icon = _icons[asset.assetType] ?? '💎';

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
                    child: Text(icon,
                        style: const TextStyle(fontSize: 20)),
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
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
  late final TextEditingController _quantity;
  late final TextEditingController _weight;
  late final TextEditingController _notes;

  double _buyPrice = 0;
  double _currentValue = 0;
  String _assetType = 'Gold';
  bool _saving = false;

  static const _types = ['Gold', 'Silber', 'Immobilie', 'Auto', 'Sonstiges'];

  bool get _isEdit => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    _description = TextEditingController(text: a?.description ?? '');
    _quantity = TextEditingController(
        text: a != null ? a.quantity.toString() : '1');
    _weight = TextEditingController(
        text: a?.weightPerUnit?.toString() ?? '');
    _notes = TextEditingController(text: a?.notes ?? '');
    _buyPrice = a?.buyPrice ?? 0;
    _currentValue = a?.currentValue ?? 0;
    _assetType = a?.assetType ?? 'Gold';
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(assetsRepositoryProvider);
      final qty =
          double.tryParse(_quantity.text.trim().replaceAll(',', '.')) ?? 1;
      final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
      final now = DateTime.now();
      final a = PhysicalAsset(
        id: widget.asset?.id ?? '',
        assetType: _assetType,
        description: _description.text.trim(),
        quantity: qty,
        weightPerUnit: weight,
        buyPrice: _buyPrice,
        currentValue: _currentValue > 0 ? _currentValue : _buyPrice,
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
    final showWeight = _assetType == 'Gold' || _assetType == 'Silber';

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
                decoration:
                    const InputDecoration(labelText: 'Typ'),
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _assetType = v ?? _assetType),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                    labelText: 'Bezeichnung (z.B. 1 Unze Krugerrand)'),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Menge'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Pflichtfeld';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (showWeight) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Gewicht', suffixText: 'g/Stk'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: CurrencyInputField(
                      label: 'Kaufpreis',
                      initialValue: _buyPrice,
                      onChanged: (v) => setState(() => _buyPrice = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CurrencyInputField(
                      label: 'Aktueller Wert',
                      initialValue: _currentValue,
                      onChanged: (v) => setState(() => _currentValue = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

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
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
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
