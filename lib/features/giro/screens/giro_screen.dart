import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/add_celebration.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/glow_icon.dart';
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
                  _TotalBanner(total: total)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, end: 0, duration: 400.ms),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(giroStreamProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _GiroCard(account: list[i])
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
        children: [
          const Text('Gesamt', style: TextStyle(color: Colors.white, fontSize: 14)),
          const Spacer(),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.format(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<Color> _iconGradient(int colorValue) {
  final base = Color(colorValue);
  final dark = HSLColor.fromColor(base).withLightness(0.35).toColor();
  return [base, dark];
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
          leading: GlowIcon(
            icon: Icons.account_balance_outlined,
            gradient: _iconGradient(account.colorValue),
            size: 36,
          ),
          title: Text(account.bankName, style: theme.textTheme.titleMedium),
          subtitle: Text(account.accountLabel, style: theme.textTheme.bodyMedium),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.format(account.balance),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: account.balance >= 0
                      ? AppColors.darkPositive
                      : AppColors.darkSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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

const _kPresetColors = [
  Color(0xFF5B8DEF), // Blue
  Color(0xFF3DC98A), // Green
  Color(0xFF20B2AA), // Teal
  Color(0xFF9B59B6), // Purple
  Color(0xFFE056A0), // Pink
  Color(0xFFF39C12), // Orange
  Color(0xFFE74C3C), // Red
  Color(0xFF5C6BC0), // Indigo
  Color(0xFFFF6B35), // Deep Orange
  Color(0xFF00BCD4), // Cyan
];

class _GiroSheetState extends ConsumerState<_GiroSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bank;
  late final TextEditingController _label;
  late final TextEditingController _notes;
  double _balance = 0;
  bool _saving = false;
  late int _colorValue;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _bank = TextEditingController(text: a?.bankName ?? '');
    _label = TextEditingController(text: a?.accountLabel ?? '');
    _notes = TextEditingController(text: a?.notes ?? '');
    _balance = a?.balance ?? 0;
    _colorValue = a?.colorValue ?? _kPresetColors.first.value;
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
        colorValue: _colorValue,
        updatedAt: now,
        createdAt: widget.account?.createdAt ?? now,
      );
      if (_isEdit) {
        await repo.update(account);
      } else {
        await repo.add(account);
      }
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await showAddCelebration(context, AddCelebrationType.giro, isEdit: _isEdit);
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
              const SizedBox(height: 16),
              Text('Icon Farbe', style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              )),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _kPresetColors.map((c) {
                  final selected = _colorValue == c.value;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = c.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
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
      ),
    );
  }
}
