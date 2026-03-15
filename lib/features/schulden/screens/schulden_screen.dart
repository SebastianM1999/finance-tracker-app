import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/schuld.dart';

class SchuldenScreen extends ConsumerWidget {
  const SchuldenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(schuldenStreamProvider);
    final total = ref.watch(schuldenTotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schulden')),
      body: stream.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          final iOwe =
              list.where((s) => s.iOwe).toList();
          final owedToMe =
              list.where((s) => !s.iOwe).toList();
          return Column(
            children: [
              _SummaryBanner(total: total, list: list),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(schuldenStreamProvider),
                  child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    if (iOwe.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Ich schulde',
                        color: AppColors.darkSecondary,
                        total: iOwe.fold(0.0, (s, d) => s + d.amount),
                      ),
                      const SizedBox(height: 8),
                      ...iOwe.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SchuldCard(schuld: d),
                          )),
                    ],
                    if (owedToMe.isNotEmpty) ...[
                      if (iOwe.isNotEmpty) const SizedBox(height: 8),
                      _SectionHeader(
                        label: 'Mir wird geschuldet',
                        color: AppColors.darkPositive,
                        total: owedToMe.fold(0.0, (s, d) => s + d.amount),
                      ),
                      const SizedBox(height: 8),
                      ...owedToMe.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SchuldCard(schuld: d),
                          )),
                    ],
                  ],
                ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Eintrag hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref, [Schuld? schuld]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SchuldSheet(schuld: schuld),
    );
  }
}

// ── Summary Banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.total, required this.list});
  final double total;
  final List<Schuld> list;

  @override
  Widget build(BuildContext context) {
    final iOweTotal =
        list.where((s) => s.iOwe).fold(0.0, (s, d) => s + d.amount);
    final owedTotal =
        list.where((s) => !s.iOwe).fold(0.0, (s, d) => s + d.amount);
    final net = owedTotal - iOweTotal;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradientSchulden,
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
              const Text('Ich schulde',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                CurrencyFormatter.format(iOweTotal),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Netto',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                CurrencyFormatter.formatPnl(net),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Mir geschuldet',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                CurrencyFormatter.format(owedTotal),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label, required this.color, required this.total});
  final String label;
  final Color color;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
                width: 4, height: 16,
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: color)),
          ],
        ),
        Text(CurrencyFormatter.format(total),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _SchuldCard extends ConsumerWidget {
  const _SchuldCard({required this.schuld});
  final Schuld schuld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color =
        schuld.iOwe ? AppColors.darkSecondary : AppColors.darkPositive;
    final isOverdue = schuld.dueDate != null &&
        schuld.dueDate!.isBefore(DateTime.now());

    return Dismissible(
      key: Key(schuld.id),
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
        title: 'Eintrag löschen',
        message:
            '${schuld.personOrInstitution} wirklich löschen?',
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(schuldenRepositoryProvider).delete(schuld.id);
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _SchuldSheet(schuld: schuld),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    schuld.iOwe
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(schuld.personOrInstitution,
                          style: theme.textTheme.titleMedium),
                      if (schuld.description != null)
                        Text(schuld.description!,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      if (schuld.dueDate != null)
                        Text(
                          'Fällig: ${DateFormatter.format(schuld.dueDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isOverdue
                                ? AppColors.darkSecondary
                                : AppColors.darkWarning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(schuld.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
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

// ── Type Toggle Button ────────────────────────────────────────────────────────

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? selectedColor : selectedColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? selectedColor : selectedColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : selectedColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
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
                  colors: AppColors.gradientSchulden),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.balance, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Keine Schulden eingetragen',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Tippe auf + um einen Eintrag hinzuzufügen',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Add / Edit Sheet ──────────────────────────────────────────────────────────

class _SchuldSheet extends ConsumerStatefulWidget {
  const _SchuldSheet({this.schuld});
  final Schuld? schuld;

  @override
  ConsumerState<_SchuldSheet> createState() => _SchuldSheetState();
}

class _SchuldSheetState extends ConsumerState<_SchuldSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _person;
  late final TextEditingController _description;

  double _amount = 0;
  String _type = 'I_OWE';
  DateTime? _dueDate;
  bool _saving = false;

  bool get _isEdit => widget.schuld != null;

  @override
  void initState() {
    super.initState();
    final s = widget.schuld;
    _person =
        TextEditingController(text: s?.personOrInstitution ?? '');
    _description =
        TextEditingController(text: s?.description ?? '');
    _amount = s?.amount ?? 0;
    _type = s?.type ?? 'I_OWE';
    _dueDate = s?.dueDate;
  }

  @override
  void dispose() {
    _person.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(schuldenRepositoryProvider);
      final now = DateTime.now();
      final s = Schuld(
        id: widget.schuld?.id ?? '',
        type: _type,
        personOrInstitution: _person.text.trim(),
        amount: _amount,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        dueDate: _dueDate,
        createdAt: widget.schuld?.createdAt ?? now,
      );
      if (_isEdit) {
        await repo.update(s);
      } else {
        await repo.add(s);
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
                _isEdit ? 'Eintrag bearbeiten' : 'Eintrag hinzufügen',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Type toggle
              Row(
                children: [
                  _TypeButton(
                    label: 'Ich schulde',
                    selected: _type == 'I_OWE',
                    selectedColor: AppColors.darkSecondary,
                    onTap: () => setState(() => _type = 'I_OWE'),
                  ),
                  const SizedBox(width: 8),
                  _TypeButton(
                    label: 'Mir geschuldet',
                    selected: _type == 'OWED_TO_ME',
                    selectedColor: AppColors.darkPositive,
                    onTap: () => setState(() => _type = 'OWED_TO_ME'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _person,
                decoration: const InputDecoration(
                    labelText: 'Person / Institution'),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),

              CurrencyInputField(
                label: 'Betrag',
                initialValue: _amount,
                onChanged: (v) => _amount = v,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                    labelText: 'Beschreibung (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Due date picker
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fälligkeitsdatum (optional)',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_dueDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _dueDate = null),
                          ),
                        const Icon(Icons.calendar_today_outlined,
                            size: 18),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  child: Text(
                    _dueDate != null
                        ? DateFormatter.format(_dueDate!)
                        : 'Kein Datum',
                    style: _dueDate != null
                        ? null
                        : theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline),
                  ),
                ),
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
