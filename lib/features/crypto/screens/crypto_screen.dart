import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/crypto_position.dart';

class CryptoTabBody extends ConsumerWidget {
  const CryptoTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _TotalBanner(total: total, list: list),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(cryptoStreamProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
        onPressed: () => _showSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Coin hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref,
      [CryptoPosition? position]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CryptoSheet(position: position),
    );
  }
}

// ── Total Banner ──────────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.total, required this.list});
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
                // Symbol badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppColors.gradientCrypto),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      position.coinSymbol.length <= 3
                          ? position.coinSymbol
                          : position.coinSymbol.substring(0, 3),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + exchange
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(position.coinName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(position.exchange,
                          style: theme.textTheme.bodyMedium),
                      Text(
                        '${position.amount} ${position.coinSymbol} · Ø ${CurrencyFormatter.format(position.buyPrice)}',
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
                    GestureDetector(
                      onTap: () => _showPriceDialog(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFA709A)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Preis aktualisieren',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFFA709A),
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
        title: const Text('Preis aktualisieren'),
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
              final updated = CryptoPosition(
                id: position.id,
                exchange: position.exchange,
                coinName: position.coinName,
                coinSymbol: position.coinSymbol,
                amount: position.amount,
                buyPrice: position.buyPrice,
                currentPrice: newPrice,
                notes: position.notes,
                createdAt: position.createdAt,
              );
              await ref.read(cryptoRepositoryProvider).update(updated);
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
  late final TextEditingController _exchange;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  double _buyPrice = 0;
  double _currentPrice = 0;
  bool _saving = false;

  bool get _isEdit => widget.position != null;

  @override
  void initState() {
    super.initState();
    final p = widget.position;
    _coinName = TextEditingController(text: p?.coinName ?? '');
    _coinSymbol = TextEditingController(text: p?.coinSymbol ?? '');
    _exchange = TextEditingController(text: p?.exchange ?? '');
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
    _exchange.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(cryptoRepositoryProvider);
      final amount =
          double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;
      final now = DateTime.now();
      final p = CryptoPosition(
        id: widget.position?.id ?? '',
        exchange: _exchange.text.trim(),
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

    final amount =
        double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
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

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _coinName,
                      decoration: const InputDecoration(
                          labelText: 'Coin Name (z.B. Bitcoin)'),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _coinSymbol,
                      decoration:
                          const InputDecoration(labelText: 'Symbol'),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _exchange,
                decoration: const InputDecoration(
                    labelText: 'Exchange (z.B. Binance, Coinbase)'),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Menge'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                  if (double.tryParse(v.trim().replaceAll(',', '.')) ==
                      null) {
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
