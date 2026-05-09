import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';
import '../../crypto/models/crypto_position.dart';
import '../../etf_stocks/models/etf_position.dart';
import '../../festgeld/models/festgeld.dart';
import '../../giro/models/giro_account.dart';
import '../../home/providers/home_providers.dart';
import '../services/financial_parser.dart';
import '../services/gemini_parser_service.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// True while the KI-Import bottom sheet is visible.
final importSheetOpenProvider = StateProvider<bool>((ref) => false);

void showImportChatSheet(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  container.read(importSheetOpenProvider.notifier).state = true;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ImportChatSheet(),
  ).whenComplete(
    () => container.read(importSheetOpenProvider.notifier).state = false,
  );
}

// ── Per-result editable field controllers ─────────────────────────────────────

class _ResultControllers {
  _ResultControllers(ParsedAsset a)
      : bank = TextEditingController(text: a.bankOrBroker ?? ''),
        label = TextEditingController(text: a.coinName ?? a.label ?? ''),
        ticker = TextEditingController(
            text: a.matchedEtf?.ticker ?? a.ticker ?? ''),
        amount = TextEditingController(
            text: a.primaryAmount != null
                ? a.primaryAmount!.toStringAsFixed(2)
                : ''),
        rate = TextEditingController(
            text: a.interestRate != null
                ? a.interestRate!.toStringAsFixed(2)
                : ''),
        months = TextEditingController(
            text: a.durationMonths?.toString() ?? ''),
        endDate = TextEditingController(
            text: a.endDate != null ? _fmt(a.endDate!) : '');

  final TextEditingController bank;
  final TextEditingController label;
  final TextEditingController ticker;
  final TextEditingController amount;
  final TextEditingController rate;
  final TextEditingController months;
  final TextEditingController endDate;

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}'
      '.${d.month.toString().padLeft(2, '0')}'
      '.${d.year}';

  void dispose() {
    bank.dispose();
    label.dispose();
    ticker.dispose();
    amount.dispose();
    rate.dispose();
    months.dispose();
    endDate.dispose();
  }
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class ImportChatSheet extends ConsumerStatefulWidget {
  const ImportChatSheet({super.key});

  @override
  ConsumerState<ImportChatSheet> createState() => _ImportChatSheetState();
}

class _ImportChatSheetState extends ConsumerState<ImportChatSheet> {
  final _hintController = TextEditingController();
  final _picker = ImagePicker();

  List<XFile> _images = [];
  List<ParsedAsset> _results = [];
  List<_ResultControllers> _controllers = [];
  bool _isAnalyzing = false;
  bool _isSavingAll = false;
  final Set<int> _savedIndices = {};
  final Set<int> _savingIndices = {};
  final Set<int> _discardedIndices = {};

  @override
  void dispose() {
    _hintController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers = [];
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isNotEmpty) {
      setState(() => _images = [..._images, ...picked]);
    }
  }

  Future<void> _analyze() async {
    if (_images.isEmpty) return;
    setState(() {
      _isAnalyzing = true;
      _results = [];
      _savedIndices.clear();
      _savingIndices.clear();
      _discardedIndices.clear();
    });
    _disposeControllers();

    try {
      final hint = _hintController.text.trim();
      final parsed = await GeminiParserService.parseImages(
        _images,
        hint.isEmpty ? null : hint,
      );

      final controllers = parsed.map(_ResultControllers.new).toList();
      // Single-image: sync bank name across all cards when user edits the first one
      if (_images.length == 1 && controllers.length > 1) {
        controllers.first.bank.addListener(() {
          final name = controllers.first.bank.text;
          for (final c in controllers.skip(1)) {
            if (c.bank.text != name) {
              c.bank.value = controllers.first.bank.value;
            }
          }
        });
      }
      setState(() {
        _results = parsed;
        _controllers = controllers;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler bei der Analyse: $e')),
        );
      }
    }
  }

  Future<void> _save(int index, ParsedAssetType selectedType) async {
    if (_savingIndices.contains(index)) return;
    setState(() => _savingIndices.add(index));

    try {
      await _saveFromControllers(index, selectedType);
      setState(() {
        _savedIndices.add(index);
        _savingIndices.remove(index);
      });
      // Close sheet when every non-discarded card is saved
      final allDone = List.generate(_results.length, (i) => i).every(
        (i) => _savedIndices.contains(i) || _discardedIndices.contains(i),
      );
      if (allDone && mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _savingIndices.remove(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _saveAll() async {
    final pending = List.generate(_results.length, (i) => i)
        .where((i) => !_savedIndices.contains(i) && !_discardedIndices.contains(i))
        .toList();
    if (pending.isEmpty) return;

    setState(() => _isSavingAll = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();

      for (final i in pending) {
        _addToBatch(batch, i, now);
      }

      await batch.commit();
      setState(() => _savedIndices.addAll(pending));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
      return;
    }

    setState(() => _isSavingAll = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${pending.length} Einträge gespeichert')),
    );
    Navigator.of(context).pop();
  }

  /// Builds the Firestore document for card [index] and adds it to [batch].
  void _addToBatch(WriteBatch batch, int index, DateTime now) {
    final ctrl = _controllers[index];
    final asset = _results[index];
    final type = asset.type == ParsedAssetType.unknown
        ? ParsedAssetType.giro
        : asset.type;

    switch (type) {
      case ParsedAssetType.giro:
        ref.read(giroRepositoryProvider).prepareBatchAdd(
              batch,
              GiroAccount(
                id: '',
                bankName: ctrl.bank.text.trim().isNotEmpty
                    ? ctrl.bank.text.trim()
                    : 'Unbekannte Bank',
                accountLabel: ctrl.label.text.trim().isNotEmpty
                    ? ctrl.label.text.trim()
                    : 'Girokonto',
                balance: _parseNum(ctrl.amount.text),
                currency: 'EUR',
                createdAt: now,
                updatedAt: now,
              ),
            );

      case ParsedAssetType.festgeld:
        final amount = _parseNum(ctrl.amount.text);
        final rate = _parseNum(ctrl.rate.text);
        final dur = int.tryParse(ctrl.months.text.trim()) ?? 12;
        final end = _parseDate(ctrl.endDate.text) ??
            DateTime(now.year, now.month + dur, now.day);
        ref.read(festgeldRepositoryProvider).prepareBatchAdd(
              batch,
              Festgeld(
                id: '',
                bankName: ctrl.bank.text.trim().isNotEmpty
                    ? ctrl.bank.text.trim()
                    : 'Unbekannte Bank',
                amount: amount,
                interestRate: rate,
                startDate: now,
                durationMonths: dur,
                endDate: end,
                projectedPayout: amount + amount * (rate / 100) * (dur / 12),
                createdAt: now,
              ),
            );

      case ParsedAssetType.etf:
        final shares = asset.shares ?? 0;
        final currentPrice = asset.currentPrice ?? 0;
        final buyPrice = asset.purchaseValue != null && shares > 0
            ? asset.purchaseValue! / shares
            : currentPrice;
        ref.read(etfRepositoryProvider).prepareBatchAdd(
              batch,
              EtfPosition(
                id: '',
                broker: ctrl.bank.text.trim(),
                name: asset.matchedEtf?.name ?? ctrl.ticker.text.trim(),
                ticker: ctrl.ticker.text.trim().isNotEmpty
                    ? ctrl.ticker.text.trim()
                    : null,
                shares: shares,
                buyPrice: buyPrice,
                currentPrice: currentPrice,
                assetType: asset.matchedEtf?.type ?? 'ETF',
                createdAt: now,
              ),
            );

      case ParsedAssetType.crypto:
        final shares = asset.shares ?? 0;
        final currentPrice = asset.currentPrice ?? 0;
        final buyPrice = asset.purchaseValue != null && shares > 0
            ? asset.purchaseValue! / shares
            : currentPrice;
        ref.read(cryptoRepositoryProvider).prepareBatchAdd(
              batch,
              CryptoPosition(
                id: '',
                exchange: ctrl.bank.text.trim().isNotEmpty
                    ? ctrl.bank.text.trim()
                    : 'Unbekannte Exchange',
                coinName: ctrl.label.text.trim().isNotEmpty
                    ? ctrl.label.text.trim()
                    : ctrl.ticker.text.trim(),
                coinSymbol: ctrl.ticker.text.trim().toUpperCase(),
                amount: shares,
                buyPrice: buyPrice,
                currentPrice: currentPrice,
                createdAt: now,
              ),
            );

      case ParsedAssetType.unknown:
        break; // skip unknown types
    }
  }

  Future<void> _saveFromControllers(
      int index, ParsedAssetType type) async {
    final ctrl = _controllers[index];
    final now = DateTime.now();

    switch (type) {
      case ParsedAssetType.giro:
        final repo = ref.read(giroRepositoryProvider);
        await repo.add(GiroAccount(
          id: '',
          bankName: ctrl.bank.text.trim().isNotEmpty
              ? ctrl.bank.text.trim()
              : 'Unbekannte Bank',
          accountLabel: ctrl.label.text.trim().isNotEmpty
              ? ctrl.label.text.trim()
              : 'Girokonto',
          balance: _parseNum(ctrl.amount.text),
          currency: 'EUR',
          createdAt: now,
          updatedAt: now,
        ));

      case ParsedAssetType.festgeld:
        final repo = ref.read(festgeldRepositoryProvider);
        final amount = _parseNum(ctrl.amount.text);
        final rate = _parseNum(ctrl.rate.text);
        final dur = int.tryParse(ctrl.months.text.trim()) ?? 12;
        final end = _parseDate(ctrl.endDate.text) ??
            DateTime(now.year, now.month + dur, now.day);
        final payout = amount + amount * (rate / 100) * (dur / 12);
        await repo.add(Festgeld(
          id: '',
          bankName: ctrl.bank.text.trim().isNotEmpty
              ? ctrl.bank.text.trim()
              : 'Unbekannte Bank',
          amount: amount,
          interestRate: rate,
          startDate: now,
          durationMonths: dur,
          endDate: end,
          projectedPayout: payout,
          createdAt: now,
        ));

      case ParsedAssetType.etf:
        final repo = ref.read(etfRepositoryProvider);
        final shares = _results[index].shares ?? 0;
        final currentPrice = _results[index].currentPrice ?? 0;
        final buyPrice = _results[index].purchaseValue != null && shares > 0
            ? _results[index].purchaseValue! / shares
            : currentPrice;
        await repo.add(EtfPosition(
          id: '',
          broker: ctrl.bank.text.trim(),
          name: _results[index].matchedEtf?.name ?? ctrl.ticker.text.trim(),
          ticker: ctrl.ticker.text.trim().isNotEmpty
              ? ctrl.ticker.text.trim()
              : null,
          shares: shares,
          buyPrice: buyPrice,
          currentPrice: currentPrice,
          assetType: _results[index].matchedEtf?.type ?? 'ETF',
          createdAt: now,
        ));

      case ParsedAssetType.crypto:
        final repo = ref.read(cryptoRepositoryProvider);
        final asset = _results[index];
        final shares = asset.shares ?? 0;
        final currentPrice = asset.currentPrice ?? 0;
        final buyPrice = asset.purchaseValue != null && shares > 0
            ? asset.purchaseValue! / shares
            : currentPrice;
        await repo.add(CryptoPosition(
          id: '',
          exchange: ctrl.bank.text.trim().isNotEmpty
              ? ctrl.bank.text.trim()
              : 'Unbekannte Exchange',
          coinName: ctrl.label.text.trim().isNotEmpty
              ? ctrl.label.text.trim()
              : (ctrl.ticker.text.trim().isNotEmpty
                  ? ctrl.ticker.text.trim()
                  : 'Unbekannt'),
          coinSymbol: ctrl.ticker.text.trim().toUpperCase(),
          amount: shares,
          buyPrice: buyPrice,
          currentPrice: currentPrice,
          createdAt: now,
        ));

      case ParsedAssetType.unknown:
        throw UnsupportedError('Bitte manuell hinzufügen.');
    }
  }

  double _parseNum(String text) {
    var s = text.trim().replaceAll(RegExp(r'[€\$\s]'), '');
    if (s.contains(',') &&
        s.contains('.') &&
        s.lastIndexOf('.') < s.lastIndexOf(',')) {
      // German: 1.234,56
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains(',')) {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0;
  }

  DateTime? _parseDate(String text) {
    final m = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(text.trim());
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final primary = AppColors.primary(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                ),
                children: [
                  const SizedBox(height: 8),
                  _Header(primary: primary),
                  const SizedBox(height: 20),
                  _ImageSection(
                    images: _images,
                    onAdd: _pickImages,
                    onRemove: (i) =>
                        setState(() => _images = [..._images]..removeAt(i)),
                  ),
                  const SizedBox(height: 16),
                  _HintField(controller: _hintController),
                  const SizedBox(height: 20),
                  _AnalyzeButton(
                    hasImages: _images.isNotEmpty,
                    isAnalyzing: _isAnalyzing,
                    onTap: _analyze,
                    primary: primary,
                  ),
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _SectionHeader(count: _results.length - _discardedIndices.length),
                    const SizedBox(height: 12),
                    ..._results.asMap().entries
                        .where((e) => !_discardedIndices.contains(e.key))
                        .map((e) {
                      final i = e.key;
                      return _EditableResultCard(
                        key: ValueKey(i),
                        asset: _results[i],
                        ctrl: _controllers[i],
                        isSaved: _savedIndices.contains(i),
                        isSaving: _savingIndices.contains(i),
                        onSave: (type) => _save(i, type),
                        onDiscard: () =>
                            setState(() => _discardedIndices.add(i)),
                      )
                          .animate()
                          .fadeIn(
                              delay: Duration(milliseconds: i * 80),
                              duration: 300.ms)
                          .slideY(
                              begin: 0.08,
                              end: 0,
                              delay: Duration(milliseconds: i * 80),
                              duration: 300.ms);
                    }),
                    // ── Save All button
                    if (_results.any((r) =>
                        !_savedIndices.contains(_results.indexOf(r)) &&
                        !_discardedIndices.contains(_results.indexOf(r)))) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingAll ? null : _saveAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF82),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFF4CAF82).withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: _isSavingAll
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline,
                                  size: 22),
                          label: Text(
                            _isSavingAll ? 'Wird gespeichert…' : 'Alle speichern',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.primary});
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KI-Import',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                'Screenshot hochladen – ich erkenne die Daten automatisch.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Image section ─────────────────────────────────────────────────────────────

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });
  final List<XFile> images;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bilder', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.add_photo_alternate_outlined,
                      color: primary, size: 28),
                ),
              ),
              ...images.asMap().entries.map((e) => _Thumbnail(
                    xfile: e.value,
                    onRemove: () => onRemove(e.key),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.xfile, required this.onRemove});
  final XFile xfile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<Uint8List>(
          future: xfile.readAsBytes(),
          builder: (context, snapshot) {
            return Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: snapshot.hasData
                    ? DecorationImage(
                        image: MemoryImage(snapshot.data!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: snapshot.hasData ? null : Colors.grey.shade300,
              ),
            );
          },
        ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child:
                  const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hint field ────────────────────────────────────────────────────────────────

class _HintField extends StatelessWidget {
  const _HintField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hinweis (optional)', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 2,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'z.B. "alle 4 sind Festgeld" oder "das ist Krypto"',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary(context)),
            filled: true,
            fillColor: AppColors.surfaceVariant(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ── Analyze button ────────────────────────────────────────────────────────────

class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({
    required this.hasImages,
    required this.isAnalyzing,
    required this.onTap,
    required this.primary,
  });
  final bool hasImages;
  final bool isAnalyzing;
  final VoidCallback onTap;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final enabled = hasImages && !isAnalyzing;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: 200.ms,
        height: 52,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.75)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : AppColors.border(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: isAnalyzing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: enabled
                            ? Colors.white
                            : AppColors.textSecondary(context),
                        size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Analysieren',
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : AppColors.textSecondary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primary(context);
    return Row(
      children: [
        Text('Erkannte Positionen',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                color: primary, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '– Werte prüfen & anpassen',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Formats a currency amount with enough decimals to avoid showing identical
/// values for current price vs Kaufwert: ≥10 → 2 dp, ≥1 → 3 dp, <1 → 4 dp.
String _fmtAmount(double v) {
  if (v >= 10) return v.toStringAsFixed(2);
  if (v >= 1) return v.toStringAsFixed(3);
  return v.toStringAsFixed(4);
}

// ── Editable result card ──────────────────────────────────────────────────────

class _EditableResultCard extends StatefulWidget {
  const _EditableResultCard({
    super.key,
    required this.asset,
    required this.ctrl,
    required this.isSaved,
    required this.isSaving,
    required this.onSave,
    required this.onDiscard,
  });
  final ParsedAsset asset;
  final _ResultControllers ctrl;
  final bool isSaved;
  final bool isSaving;
  final void Function(ParsedAssetType selectedType) onSave;
  final VoidCallback onDiscard;

  @override
  State<_EditableResultCard> createState() => _EditableResultCardState();
}

class _EditableResultCardState extends State<_EditableResultCard> {
  final _formKey = GlobalKey<FormState>();
  late ParsedAssetType _type;

  static const _typeLabels = {
    ParsedAssetType.giro: 'Girokonto',
    ParsedAssetType.festgeld: 'Festgeld',
    ParsedAssetType.etf: 'ETF / Aktie',
    ParsedAssetType.crypto: 'Krypto',
    ParsedAssetType.unknown: 'Unbekannt',
  };
  static const _typeGradients = {
    ParsedAssetType.giro: AppColors.gradientGiro,
    ParsedAssetType.festgeld: AppColors.gradientFestgeld,
    ParsedAssetType.etf: AppColors.gradientEtf,
    ParsedAssetType.crypto: AppColors.gradientCrypto,
    ParsedAssetType.unknown: AppColors.gradientGiro,
  };
  static const _typeIcons = {
    ParsedAssetType.giro: FontAwesomeIcons.buildingColumns,
    ParsedAssetType.festgeld: FontAwesomeIcons.piggyBank,
    ParsedAssetType.etf: FontAwesomeIcons.chartLine,
    ParsedAssetType.crypto: FontAwesomeIcons.coins,
    ParsedAssetType.unknown: FontAwesomeIcons.circleQuestion,
  };

  @override
  void initState() {
    super.initState();
    _type = widget.asset.type == ParsedAssetType.unknown
        ? ParsedAssetType.giro
        : widget.asset.type;
  }

  bool get _canAutoSave {
    if (_type == ParsedAssetType.giro || _type == ParsedAssetType.festgeld) {
      return true;
    }
    if (_type == ParsedAssetType.etf) {
      return widget.ctrl.ticker.text.isNotEmpty &&
          widget.asset.shares != null &&
          widget.asset.currentPrice != null;
    }
    if (_type == ParsedAssetType.crypto) {
      return widget.ctrl.ticker.text.isNotEmpty &&
          widget.asset.shares != null;
    }
    return false;
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(_type);
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _typeGradients[_type]!;
    final icon = _typeIcons[_type]!;
    final isSaved = widget.isSaved;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSaved
                ? AppColors.positive(context).withValues(alpha: 0.4)
                : AppColors.border(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Coloured top bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(
                  children: [
                    FaIcon(icon, color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      _typeLabels[_type]!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    // Confidence badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(widget.asset.confidence * 100).round()}% erkannt',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Type selector chips
                    if (!isSaved) ...[
                      _TypeSelector(
                        selected: _type,
                        onChanged: (t) => setState(() => _type = t),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Common field: Bank name
                    _InputField(
                      label: 'Bank / Anbieter',
                      controller: widget.ctrl.bank,
                      enabled: !isSaved,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Pflichtfeld'
                          : null,
                    ),
                    const SizedBox(height: 10),

                    // ── Giro fields
                    if (_type == ParsedAssetType.giro) ...[
                      _InputField(
                        label: 'Bezeichnung',
                        controller: widget.ctrl.label,
                        enabled: !isSaved,
                        hint: 'z.B. Girokonto, Gehaltskonto',
                      ),
                      const SizedBox(height: 10),
                      _InputField(
                        label: 'Kontostand (€)',
                        controller: widget.ctrl.amount,
                        enabled: !isSaved,
                        keyboard: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]')),
                        ],
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── Festgeld fields
                    if (_type == ParsedAssetType.festgeld) ...[
                      _InputField(
                        label: 'Betrag (€)',
                        controller: widget.ctrl.amount,
                        enabled: !isSaved,
                        keyboard: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]')),
                        ],
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: 'Zinssatz (% p.a.)',
                              controller: widget.ctrl.rate,
                              enabled: !isSaved,
                              keyboard: TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d.,]')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InputField(
                              label: 'Laufzeit (Monate)',
                              controller: widget.ctrl.months,
                              enabled: !isSaved,
                              keyboard: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _InputField(
                        label: 'Fälligkeitsdatum (TT.MM.JJJJ)',
                        controller: widget.ctrl.endDate,
                        enabled: !isSaved,
                        hint: '31.12.2026',
                        keyboard: TextInputType.datetime,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── ETF: ticker field + detected data
                    if (_type == ParsedAssetType.etf) ...[
                      _InputField(
                        label: 'Ticker / ISIN',
                        controller: widget.ctrl.ticker,
                        enabled: !isSaved,
                        hint: 'z.B. EUNL.DE',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── ETF: show detected fund name / shares / purchase value
                    if (_type == ParsedAssetType.etf &&
                        (widget.asset.ticker != null ||
                            widget.asset.shares != null)) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.asset.ticker != null)
                              Text(
                                widget.asset.ticker!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            if (widget.asset.shares != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${widget.asset.shares} Stück'
                                '${widget.asset.currentPrice != null ? ' · ${widget.asset.currentPrice!.toStringAsFixed(4)} EUR' : ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.textSecondary(context)),
                              ),
                            ],
                            if (widget.asset.purchaseValue != null) ...[
                              const SizedBox(height: 6),
                              const Divider(height: 1),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Kaufwert (errechnet)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppColors.textSecondary(
                                                  context))),
                                  Text(
                                    '${_fmtAmount(widget.asset.purchaseValue!)} EUR',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              if (widget.asset.gainPercent != null)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Rendite (Seit Kauf)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppColors.textSecondary(
                                                    context))),
                                    Text(
                                      '${widget.asset.gainPercent! >= 0 ? '+' : ''}${widget.asset.gainPercent!.toStringAsFixed(2)} %',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: widget.asset.gainPercent! >= 0
                                                ? AppColors.positive(context)
                                                : const Color(0xFFFF6B6B),
                                          ),
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── Crypto: detected coin data (read-only info box)
                    if (_type == ParsedAssetType.crypto &&
                        (widget.asset.shares != null ||
                            widget.asset.primaryAmount != null)) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.asset.shares != null)
                              Text(
                                '${widget.asset.shares} ${widget.asset.ticker ?? ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            if (widget.asset.primaryAmount != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${widget.asset.primaryAmount!.toStringAsFixed(2)} EUR',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color:
                                            AppColors.textSecondary(context)),
                              ),
                            ],
                            if (widget.asset.gainPercent != null) ...[
                              const SizedBox(height: 6),
                              const Divider(height: 1),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Rendite (Seit Kauf)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppColors.textSecondary(
                                                  context))),
                                  Text(
                                    '${widget.asset.gainPercent! >= 0 ? '+' : ''}${widget.asset.gainPercent!.toStringAsFixed(2)} %',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: widget.asset.gainPercent! >= 0
                                              ? AppColors.positive(context)
                                              : const Color(0xFFFF6B6B),
                                        ),
                                  ),
                                ],
                              ),
                              if (widget.asset.purchaseValue != null)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Kaufwert (errechnet)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppColors.textSecondary(
                                                    context))),
                                    Text(
                                      '${_fmtAmount(widget.asset.purchaseValue!)} EUR',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── ETF/Crypto warning + action buttons (react to ticker edits)
                    ListenableBuilder(
                      listenable: widget.ctrl.ticker,
                      builder: (context, _) => Column(
                        children: [
                          if (_type == ParsedAssetType.etf && !_canAutoSave) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warning(context)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16,
                                      color: AppColors.warning(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ticker eingeben um direkt zu speichern.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.warning(context)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          AnimatedSwitcher(
                            duration: 250.ms,
                            child: isSaved
                                ? _SavedRow(key: const ValueKey('saved'))
                                : _ActionRow(
                                    key: const ValueKey('actions'),
                                    canSave: _canAutoSave,
                                    isSaving: widget.isSaving,
                                    onSave: _handleSave,
                                    onDiscard: widget.onDiscard,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type selector ─────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});
  final ParsedAssetType selected;
  final void Function(ParsedAssetType) onChanged;

  static const _options = [
    (ParsedAssetType.giro, 'Giro'),
    (ParsedAssetType.festgeld, 'Festgeld'),
    (ParsedAssetType.etf, 'ETF'),
    (ParsedAssetType.crypto, 'Krypto'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary(context);
    return Row(
      children: _options.map((opt) {
        final (type, label) = opt;
        final active = type == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: 150.ms,
                height: 30,
                decoration: BoxDecoration(
                  color: active
                      ? primary.withValues(alpha: 0.12)
                      : AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? primary.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? primary
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Input field ───────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.hint,
    this.keyboard,
    this.inputFormatters,
    this.validator,
  });
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? hint;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          validator: validator,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary(context)),
            filled: true,
            fillColor: enabled
                ? AppColors.surfaceVariant(context)
                : AppColors.surfaceVariant(context).withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.canSave,
    required this.isSaving,
    required this.onSave,
    required this.onDiscard,
  });
  final bool canSave;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary(context);
    return Row(
      children: [
        // Discard
        Expanded(
          child: GestureDetector(
            onTap: onDiscard,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Verwerfen',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Save / confirm
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: canSave ? onSave : null,
            child: AnimatedContainer(
              duration: 150.ms,
              height: 42,
              decoration: BoxDecoration(
                gradient: canSave
                    ? LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.75)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: canSave ? null : AppColors.border(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 15,
                              color: canSave
                                  ? Colors.white
                                  : AppColors.textSecondary(context)),
                          const SizedBox(width: 5),
                          Text(
                            'Bestätigen & Speichern',
                            style: TextStyle(
                              color: canSave
                                  ? Colors.white
                                  : AppColors.textSecondary(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Saved row ─────────────────────────────────────────────────────────────────

class _SavedRow extends StatelessWidget {
  const _SavedRow({super.key});

  @override
  Widget build(BuildContext context) {
    final positive = AppColors.positive(context);
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: positive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: positive.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: positive),
            const SizedBox(width: 6),
            Text(
              'Gespeichert',
              style: TextStyle(
                  color: positive,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.92, 0.92), duration: 200.ms);
  }
}
