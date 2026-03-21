import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/number_utils.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/add_celebration.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/currency_input_field.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_providers.dart';
import '../models/festgeld.dart';

class FestgeldScreen extends StatelessWidget {
  const FestgeldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Festgeld')),
      body: const FestgeldTabBody(),
    );
  }
}

/// Embeddable body used inside the Investments tab.
class FestgeldTabBody extends ConsumerWidget {
  const FestgeldTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(festgeldStreamProvider);
    final total = ref.watch(festgeldTotalProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: accounts.when(
        loading: () => const ShimmerList(cardHeight: 120),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : Column(
                children: [
                  _TotalBanner(total: total, list: list)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, end: 0, duration: 400.ms),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(festgeldStreamProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _FestgeldCard(item: list[i])
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: i.clamp(0, 4) * 55),
                              duration: 300.ms,
                            )
                            .slideY(
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
        label: const Text('Festgeld hinzufügen'),
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref, [Festgeld? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FestgeldSheet(item: item),
    );
  }
}

// ── Total Banner ──────────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.total, required this.list});
  final double total;
  final List<Festgeld> list;

  @override
  Widget build(BuildContext context) {
    final totalInterest = list.fold(
      0.0,
      (s, f) => s + (f.projectedPayout - f.amount),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradientFestgeld,
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
                const Text('Gesamt angelegt',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Zinsertrag',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '+${CurrencyFormatter.format(totalInterest)}',
                  style: const TextStyle(
                    color: Color(0xFFB8F5D8),
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

class _FestgeldCard extends ConsumerWidget {
  const _FestgeldCard({required this.item});
  final Festgeld item;

  /// Single color used for bar, left accent, and bottom chip.
  /// Red is reserved exclusively for expired cards.
  Color? _urgencyColor(bool isExpired, double progress) {
    if (isExpired) return AppColors.darkSecondary;
    if (progress >= 0.90) return const Color(0xFF4FC770);
    if (progress >= 0.75) return AppColors.darkPositive;
    return null; // not urgent yet
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final daysLeft = item.daysRemaining;
    final isExpired = daysLeft < 0;
    final daysLabel = DateFormatter.daysRemaining(item.endDate);

    final urgency = _urgencyColor(isExpired, item.progress);
    final barColor = urgency ?? AppColors.darkPrimary;
    final showAccent = urgency != null;
    final statusColor = urgency; // chip only shown when urgency != null

    return Dismissible(
      key: Key(item.id),
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
        title: 'Festgeld löschen',
        message: '${item.bankName} wirklich löschen?',
      ),
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        await ref.read(festgeldRepositoryProvider).delete(item.id);
        await NotificationService.instance.cancelFestgeldNotifications(item.id);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _FestgeldSheet(item: item),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left urgency accent bar
                if (showAccent)
                  Container(width: 3, color: urgency),

                // Card content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        showAccent ? 13 : 16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: AppColors.gradientFestgeld,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.savings_outlined,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.bankName,
                                      style: theme.textTheme.titleMedium),
                                  Text(
                                    '${item.durationMonths} Monate · ${item.interestRate.toStringAsFixed(2)} % p.a.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      CurrencyFormatter.format(item.amount),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    '→ ${CurrencyFormatter.format(item.projectedPayout)}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color: AppColors.darkPositive),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 5,
                            backgroundColor: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.25),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Date row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${DateFormatter.format(item.startDate)} – ${DateFormatter.format(item.endDate)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (statusColor != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  daysLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Text(
                                daysLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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
                  const LinearGradient(colors: AppColors.gradientFestgeld),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.savings_outlined,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Noch kein Festgeld',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Tippe auf + um ein Festgeld hinzuzufügen',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Add / Edit Sheet ──────────────────────────────────────────────────────────

class _FestgeldSheet extends ConsumerStatefulWidget {
  const _FestgeldSheet({this.item});
  final Festgeld? item;

  @override
  ConsumerState<_FestgeldSheet> createState() => _FestgeldSheetState();
}

class _FestgeldSheetState extends ConsumerState<_FestgeldSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _bank;
  late final TextEditingController _duration;
  late final TextEditingController _rate;
  late final TextEditingController _notes;

  double _amount = 0;
  DateTime _startDate = DateTime.now();
  bool _notificationsEnabled = true;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final f = widget.item;
    _bank = TextEditingController(text: f?.bankName ?? '');
    _duration = TextEditingController(
        text: f?.durationMonths.toString() ?? '');
    _rate = TextEditingController(
        text: f != null ? f.interestRate.toStringAsFixed(2) : '');
    _notes = TextEditingController(text: f?.notes ?? '');
    _amount = f?.amount ?? 0;
    _startDate = f?.startDate ?? DateTime.now();
    _notificationsEnabled = f?.notificationsEnabled ?? true;
  }

  @override
  void dispose() {
    _bank.dispose();
    _duration.dispose();
    _rate.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _calcEndDate(DateTime start, int months) {
    return DateTime(start.year, start.month + months, start.day);
  }

  Future<void> _promptCalendarEntry({
    required String bankName,
    required double amount,
    required double projectedPayout,
    required DateTime endDate,
  }) async {
    if (kIsWeb) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kalender-Eintrag'),
        content: Text(
          'Soll der Fälligkeitstermin (${DateFormatter.format(endDate)}) in deinen Kalender eingetragen werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nein'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _launchCalendar(
        bankName: bankName,
        amount: amount,
        projectedPayout: projectedPayout,
        endDate: endDate,
      );
    }
  }

  Future<void> _launchCalendar({
    required String bankName,
    required double amount,
    required double projectedPayout,
    required DateTime endDate,
  }) async {
    // endDate +1 day because Google Calendar uses exclusive end dates
    // for all-day events (iCalendar format). This makes it display as
    // a single day on the correct date.
    final ok = await Add2Calendar.addEvent2Cal(Event(
      title: 'Festgeld fällig: $bankName',
      description:
          '${CurrencyFormatter.format(amount)} + Zinsen → ${CurrencyFormatter.format(projectedPayout)}',
      startDate: DateTime(endDate.year, endDate.month, endDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day + 1),
      allDay: true,
    ));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kalender-App nicht gefunden')),
      );
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(festgeldRepositoryProvider);
      final months = int.parse(_duration.text.trim());
      final rate = double.parse(_rate.text.trim().replaceAll(',', '.'));
      final endDate = _calcEndDate(_startDate, months);
      final payout = NumberUtils.calcFestgeldPayout(_amount, rate, months);
      final now = DateTime.now();

      final f = Festgeld(
        id: widget.item?.id ?? '',
        bankName: _bank.text.trim(),
        amount: _amount,
        interestRate: rate,
        startDate: _startDate,
        durationMonths: months,
        endDate: endDate,
        projectedPayout: payout,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        notificationsEnabled: _notificationsEnabled,
        notifiedDays: widget.item?.notifiedDays ?? [],
        scheduledNotificationIds: [],
        createdAt: widget.item?.createdAt ?? now,
      );

      String festgeldId;
      if (_isEdit) {
        festgeldId = widget.item!.id;
      } else {
        // Save first to get the stable Firestore ID, then schedule with it
        final docRef = await repo.add(f);
        festgeldId = docRef.id;
      }

      List<int> notifIds = [];
      if (_notificationsEnabled) {
        notifIds = await NotificationService.instance
            .scheduleFestgeldNotifications(
          festgeldId: festgeldId,
          bankName: f.bankName,
          amount: f.amount,
          endDate: f.endDate,
        );
      }

      final fWithIds = Festgeld(
        id: festgeldId,
        bankName: f.bankName,
        amount: f.amount,
        interestRate: f.interestRate,
        startDate: f.startDate,
        durationMonths: f.durationMonths,
        endDate: f.endDate,
        projectedPayout: f.projectedPayout,
        notes: f.notes,
        notificationsEnabled: f.notificationsEnabled,
        notifiedDays: f.notifiedDays,
        scheduledNotificationIds: notifIds,
        createdAt: f.createdAt,
      );

      // Always update — for new entries this writes the notifIds back;
      // for edits this overwrites with fresh schedule.
      await repo.update(fWithIds);

      // Celebrate add or edit
      if (mounted) {
        // ignore: use_build_context_synchronously
        await showAddCelebration(context, AddCelebrationType.festgeld, isEdit: _isEdit);
      }

      // For new entries, ask about calendar BEFORE closing the sheet
      // so the context is still valid when the intent fires.
      if (!_isEdit && mounted) {
        await _promptCalendarEntry(
          bankName: fWithIds.bankName,
          amount: fWithIds.amount,
          projectedPayout: fWithIds.projectedPayout,
          endDate: fWithIds.endDate,
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

    // Preview payout
    final months = int.tryParse(_duration.text) ?? 0;
    final rate =
        double.tryParse(_rate.text.replaceAll(',', '.')) ?? 0;
    final previewPayout = months > 0 && rate > 0
        ? NumberUtils.calcFestgeldPayout(_amount, rate, months)
        : null;
    final endDatePreview =
        months > 0 ? _calcEndDate(_startDate, months) : null;

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
                // Handle
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
                  _isEdit ? 'Festgeld bearbeiten' : 'Festgeld hinzufügen',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 20),

                // Bank name
                TextFormField(
                  controller: _bank,
                  decoration: const InputDecoration(
                      labelText: 'Bank (z.B. ING, DKB)'),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 12),

                // Amount
                CurrencyInputField(
                  label: 'Anlagebetrag',
                  initialValue: _amount,
                  onChanged: (v) => setState(() => _amount = v),
                ),
                const SizedBox(height: 12),

                // Duration + Rate side by side
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Laufzeit',
                          suffixText: 'Monate',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Pflichtfeld';
                          }
                          if (int.tryParse(v.trim()) == null) {
                            return 'Ungültig';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Zinssatz',
                          suffixText: '% p.a.',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Pflichtfeld';
                          }
                          if (double.tryParse(
                                  v.trim().replaceAll(',', '.')) ==
                              null) {
                            return 'Ungültig';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Start date picker
                InkWell(
                  onTap: _pickStartDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Startdatum',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(DateFormatter.format(_startDate)),
                  ),
                ),
                const SizedBox(height: 12),

                // Preview card
                if (previewPayout != null && endDatePreview != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: AppColors.gradientFestgeld),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Auszahlung',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(
                              CurrencyFormatter.format(previewPayout),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Fällig am',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(
                              DateFormatter.format(endDatePreview),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (previewPayout != null) const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notes,
                  decoration:
                      const InputDecoration(labelText: 'Notizen (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Notifications toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fälligkeits-Erinnerungen'),
                  subtitle: const Text('30, 7, 1 Tag vorher'),
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                const SizedBox(height: 16),

                // Save button
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
