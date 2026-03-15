import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/etf_position.dart';

class EtfTabBody extends ConsumerWidget {
  const EtfTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _TotalBanner(total: total, list: list),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(etfStreamProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
        onPressed: () => _showSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Position hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref,
      [EtfPosition? position]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EtfSheet(position: position),
    );
  }
}

// ── Total Banner ──────────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.total, required this.list});
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
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppColors.gradientEtf),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      position.assetType == 'ETF' ? 'ETF' : '📈',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + broker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(position.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${position.broker}${position.ticker != null ? ' · ${position.ticker}' : ''}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${position.shares} Anteile · Ø ${CurrencyFormatter.format(position.buyPrice)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Value + P&L
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
                    const SizedBox(height: 4),
                    // Update price button
                    GestureDetector(
                      onTap: () => _showPriceDialog(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4FACFE)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Preis aktualisieren',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF4FACFE),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
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

  void _showPriceDialog(BuildContext context, WidgetRef ref) {
    double newPrice = position.currentPrice;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Preis aktualisieren'),
        content: CurrencyInputField(
          label: 'Aktueller Kurs',
          initialValue: position.currentPrice,
          onChanged: (v) => newPrice = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = EtfPosition(
                id: position.id,
                broker: position.broker,
                name: position.name,
                ticker: position.ticker,
                shares: position.shares,
                buyPrice: position.buyPrice,
                currentPrice: newPrice,
                currency: position.currency,
                assetType: position.assetType,
                lastPriceUpdate: DateTime.now(),
                notes: position.notes,
                createdAt: position.createdAt,
              );
              await ref.read(etfRepositoryProvider).update(updated);
            },
            child: const Text('Speichern'),
          ),
        ],
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
            child: const Icon(Icons.trending_up, color: Colors.white, size: 36),
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
  late final TextEditingController _broker;
  late final TextEditingController _shares;
  late final TextEditingController _notes;

  double _buyPrice = 0;
  double _currentPrice = 0;
  String _assetType = 'ETF';
  bool _saving = false;

  bool get _isEdit => widget.position != null;

  @override
  void initState() {
    super.initState();
    final p = widget.position;
    _name = TextEditingController(text: p?.name ?? '');
    _ticker = TextEditingController(text: p?.ticker ?? '');
    _broker = TextEditingController(text: p?.broker ?? '');
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
    _broker.dispose();
    _shares.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(etfRepositoryProvider);
      final shares =
          double.tryParse(_shares.text.trim().replaceAll(',', '.')) ?? 0;
      final now = DateTime.now();
      final p = EtfPosition(
        id: widget.position?.id ?? '',
        broker: _broker.text.trim(),
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
        await repo.add(p);
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

    final shares =
        double.tryParse(_shares.text.replaceAll(',', '.')) ?? 0;
    final previewValue =
        shares > 0 && _currentPrice > 0 ? shares * _currentPrice : null;
    final previewPnl = previewValue != null && _buyPrice > 0
        ? previewValue - (shares * _buyPrice)
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
                _isEdit ? 'Position bearbeiten' : 'Position hinzufügen',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // ETF / Stock toggle
              SegmentedButton<String>(
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ticker,
                      decoration: const InputDecoration(
                          labelText: 'Ticker (optional)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _broker,
                      decoration: const InputDecoration(
                          labelText: 'Broker'),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shares,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Anzahl Anteile'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                  if (double.tryParse(v.trim().replaceAll(',', '.')) == null) {
                    return 'Ungültig';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
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
                      onChanged: (v) => setState(() => _currentPrice = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Preview
              if (previewValue != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppColors.gradientEtf),
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
                                    color: Colors.white70, fontSize: 12)),
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
              if (previewValue != null) const SizedBox(height: 12),

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
