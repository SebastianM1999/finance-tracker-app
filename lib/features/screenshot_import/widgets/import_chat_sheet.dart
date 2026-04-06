import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../festgeld/models/festgeld.dart';
import '../../giro/models/giro_account.dart';
import '../../home/providers/home_providers.dart';
import '../services/financial_parser.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

void showImportChatSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ImportChatSheet(),
  );
}

// ── Per-result editable field controllers ─────────────────────────────────────

class _ResultControllers {
  _ResultControllers(ParsedAsset a)
      : bank = TextEditingController(text: a.bankOrBroker ?? ''),
        label = TextEditingController(text: a.label ?? ''),
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
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _picker = ImagePicker();

  List<XFile> _images = [];
  List<ParsedAsset> _results = [];
  List<_ResultControllers> _controllers = [];
  bool _isAnalyzing = false;
  final Set<int> _savedIndices = {};
  final Set<int> _savingIndices = {};
  final Set<int> _discardedIndices = {};

  @override
  void dispose() {
    _hintController.dispose();
    _textRecognizer.close();
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
      final texts = <String>[];
      for (final img in _images) {
        final input = InputImage.fromFilePath(img.path);
        final recognized = await _textRecognizer.processImage(input);
        texts.add(recognized.text);
      }

      final hint = _hintController.text.trim();
      final parsed = FinancialParser.parseAll(texts, hint.isEmpty ? null : hint);

      setState(() {
        _results = parsed;
        _controllers = parsed.map(_ResultControllers.new).toList();
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
    } catch (e) {
      setState(() => _savingIndices.remove(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
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
      case ParsedAssetType.crypto:
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
                    file: File(e.value.path),
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
  const _Thumbnail({required this.file, required this.onRemove});
  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(file),
              fit: BoxFit.cover,
            ),
          ),
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
        Text(
          '– Werte prüfen & anpassen',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }
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

  bool get _canAutoSave =>
      _type == ParsedAssetType.giro || _type == ParsedAssetType.festgeld;

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(_type);
  }

  Color _confidenceColor(double v) {
    if (v >= 0.7) return const Color(0xFF4CAF82);
    if (v >= 0.4) return const Color(0xFFFFB347);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    ],

                    // ── ETF / Crypto: manual note
                    if (_type == ParsedAssetType.etf ||
                        _type == ParsedAssetType.crypto) ...[
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
                                _type == ParsedAssetType.etf
                                    ? 'ETF/Aktien benötigen Ticker & Stückzahl. Bitte manuell unter "ETF & Aktien" hinzufügen.'
                                    : 'Krypto benötigt Coin & Menge. Bitte manuell unter "Krypto" hinzufügen.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning(context)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Action buttons
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
