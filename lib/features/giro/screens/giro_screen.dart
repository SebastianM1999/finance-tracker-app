import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/giro_account.dart';

class GiroScreen extends ConsumerWidget {
  const GiroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(giroStreamProvider);
    final total = ref.watch(giroTotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Giro Konten')),
      body: accounts.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : Column(
                children: [
                  _TotalBanner(total: total),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(giroStreamProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) =>
                            _GiroCard(account: list[i]),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Konto hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref, [GiroAccount? account]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiroSheet(account: account),
    );
  }
}

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradientGiro,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Gesamt', style: TextStyle(color: Colors.white, fontSize: 14)),
          Text(
            CurrencyFormatter.format(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GiroCard extends ConsumerWidget {
  const _GiroCard({required this.account});
  final GiroAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dismissible(
      key: Key(account.id),
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
        title: 'Konto löschen',
        message: '${account.bankName} – ${account.accountLabel} wirklich löschen?',
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(giroRepositoryProvider).delete(account.id);
      },
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.gradientGiro),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 20),
          ),
          title: Text(account.bankName, style: theme.textTheme.titleMedium),
          subtitle: Text(account.accountLabel, style: theme.textTheme.bodyMedium),
          trailing: Text(
            CurrencyFormatter.format(account.balance),
            style: theme.textTheme.titleMedium?.copyWith(
              color: account.balance >= 0
                  ? AppColors.darkPositive
                  : AppColors.darkSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _GiroSheet(account: account),
          ),
        ),
      ),
    );
  }
}

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
              gradient: const LinearGradient(colors: AppColors.gradientGiro),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Noch keine Konten', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Tippe auf + um ein Konto hinzuzufügen',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Add / Edit Sheet ──────────────────────────────────────────────────────────

class _GiroSheet extends ConsumerStatefulWidget {
  const _GiroSheet({this.account});
  final GiroAccount? account;

  @override
  ConsumerState<_GiroSheet> createState() => _GiroSheetState();
}

class _GiroSheetState extends ConsumerState<_GiroSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bank;
  late final TextEditingController _label;
  late final TextEditingController _notes;
  double _balance = 0;
  bool _saving = false;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _bank = TextEditingController(text: a?.bankName ?? '');
    _label = TextEditingController(text: a?.accountLabel ?? '');
    _notes = TextEditingController(text: a?.notes ?? '');
    _balance = a?.balance ?? 0;
  }

  @override
  void dispose() {
    _bank.dispose();
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(giroRepositoryProvider);
      final now = DateTime.now();
      final account = GiroAccount(
        id: widget.account?.id ?? '',
        bankName: _bank.text.trim(),
        accountLabel: _label.text.trim(),
        balance: _balance,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        updatedAt: now,
        createdAt: widget.account?.createdAt ?? now,
      );
      if (_isEdit) {
        await repo.update(account);
      } else {
        await repo.add(account);
      }
      HapticFeedback.lightImpact();
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
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
                _isEdit ? 'Konto bearbeiten' : 'Konto hinzufügen',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _bank,
                decoration: const InputDecoration(labelText: 'Bank (z.B. DKB, Sparkasse)'),
                validator: (v) => v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(labelText: 'Bezeichnung (z.B. Gehaltskonto)'),
                validator: (v) => v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),
              CurrencyInputField(
                label: 'Kontostand',
                initialValue: _balance,
                onChanged: (v) => _balance = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notizen (optional)'),
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
                      : Text(_isEdit ? 'Speichern' : 'Hinzufügen',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
