import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
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
  bool _isAnalyzing = false;
  final Set<int> _savedIndices = {};
  final Set<int> _savingIndices = {};

  @override
  void dispose() {
    _hintController.dispose();
    _textRecognizer.close();
    super.dispose();
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
    });

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

  Future<void> _save(int index) async {
    if (_savingIndices.contains(index)) return;
    setState(() => _savingIndices.add(index));

    try {
      final asset = _results[index];
      await _saveAsset(asset);
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

  Future<void> _saveAsset(ParsedAsset asset) async {
    final now = DateTime.now();

    switch (asset.type) {
      case ParsedAssetType.giro:
        final repo = ref.read(giroRepositoryProvider);
        await repo.add(GiroAccount(
          id: '',
          bankName: asset.bankOrBroker ?? 'Unbekannte Bank',
          accountLabel: asset.label ?? 'Girokonto',
          balance: asset.primaryAmount ?? 0,
          currency: 'EUR',
          createdAt: now,
          updatedAt: now,
        ));

      case ParsedAssetType.festgeld:
        final repo = ref.read(festgeldRepositoryProvider);
        final rate = asset.interestRate ?? 0;
        final months = asset.durationMonths ?? 12;
        final amount = asset.primaryAmount ?? 0;
        final endDate = asset.endDate ??
            DateTime(now.year, now.month + months, now.day);
        // Simple interest payout projection
        final payout = amount + amount * (rate / 100) * (months / 12);
        await repo.add(Festgeld(
          id: '',
          bankName: asset.bankOrBroker ?? 'Unbekannte Bank',
          amount: amount,
          interestRate: rate,
          startDate: now,
          durationMonths: months,
          endDate: endDate,
          projectedPayout: payout,
          createdAt: now,
        ));

      // ETF and Crypto are added with a note so the user can complete missing
      // fields (shares, ticker, etc.) in the dedicated screens.
      case ParsedAssetType.etf:
      case ParsedAssetType.crypto:
      case ParsedAssetType.unknown:
        // Not saved automatically – the result card shows a hint instead.
        throw UnsupportedError(
          'ETF/Crypto requires additional fields. Please add manually.',
        );
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = AppColors.surface(context);
    final primary = AppColors.primary(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Drag handle
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
            // ── Scrollable body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                    const SizedBox(height: 24),
                    _ResultsSection(
                      results: _results,
                      savedIndices: _savedIndices,
                      savingIndices: _savingIndices,
                      onSave: _save,
                    ),
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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
                  color: AppColors.textSecondary(context),
                ),
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
  final void Function(int index) onRemove;

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
              // Add button
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: primary.withValues(alpha: 0.3),
                        style: BorderStyle.solid),
                  ),
                  child: Icon(Icons.add_photo_alternate_outlined,
                      color: primary, size: 28),
                ),
              ),
              // Thumbnails
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
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
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
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(context),
            ),
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
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: enabled ? Colors.white : AppColors.textSecondary(context),
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

// ── Results section ───────────────────────────────────────────────────────────

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.results,
    required this.savedIndices,
    required this.savingIndices,
    required this.onSave,
  });
  final List<ParsedAsset> results;
  final Set<int> savedIndices;
  final Set<int> savingIndices;
  final void Function(int) onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Erkannte Positionen',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${results.length}',
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...results.asMap().entries.map((e) {
          final i = e.key;
          return _ResultCard(
            asset: e.value,
            isSaved: savedIndices.contains(i),
            isSaving: savingIndices.contains(i),
            onSave: () => onSave(i),
          )
              .animate()
              .fadeIn(delay: Duration(milliseconds: i * 80), duration: 300.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: Duration(milliseconds: i * 80),
                duration: 300.ms,
              );
        }),
      ],
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.asset,
    required this.isSaved,
    required this.isSaving,
    required this.onSave,
  });
  final ParsedAsset asset;
  final bool isSaved;
  final bool isSaving;
  final VoidCallback onSave;

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

  static const _typeLabels = {
    ParsedAssetType.giro: 'Girokonto',
    ParsedAssetType.festgeld: 'Festgeld',
    ParsedAssetType.etf: 'ETF / Aktie',
    ParsedAssetType.crypto: 'Krypto',
    ParsedAssetType.unknown: 'Unbekannt',
  };

  bool get _canAutoSave =>
      asset.type == ParsedAssetType.giro ||
      asset.type == ParsedAssetType.festgeld;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = _typeGradients[asset.type]!;
    final icon = _typeIcons[asset.type]!;
    final typeLabel = _typeLabels[asset.type]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(icon, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(typeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary(context),
                          )),
                      Text(
                        asset.bankOrBroker ?? 'Unbekannte Bank',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // Confidence badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _confidenceColor(asset.confidence)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(asset.confidence * 100).round()}%',
                    style: TextStyle(
                      color: _confidenceColor(asset.confidence),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Extracted fields
            if (asset.primaryAmount != null)
              _Field(
                label: asset.type == ParsedAssetType.giro
                    ? 'Kontostand'
                    : 'Betrag',
                value: CurrencyFormatter.format(asset.primaryAmount!),
                highlight: true,
              ),
            if (asset.label != null)
              _Field(label: 'Bezeichnung', value: asset.label!),
            if (asset.interestRate != null)
              _Field(
                  label: 'Zinssatz',
                  value: '${asset.interestRate!.toStringAsFixed(2)} % p.a.'),
            if (asset.durationMonths != null)
              _Field(
                  label: 'Laufzeit',
                  value: '${asset.durationMonths} Monate'),
            if (asset.endDate != null)
              _Field(
                label: 'Fälligkeit',
                value:
                    '${asset.endDate!.day.toString().padLeft(2, '0')}.${asset.endDate!.month.toString().padLeft(2, '0')}.${asset.endDate!.year}',
              ),
            if (asset.ticker != null)
              _Field(label: 'Ticker / ISIN', value: asset.ticker!),
            if (asset.shares != null)
              _Field(label: 'Anteile', value: '${asset.shares}'),
            if (asset.coinName != null)
              _Field(label: 'Coin', value: asset.coinName!),

            // ── Note for unsupported auto-save types
            if (!_canAutoSave) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.warning(context).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.warning(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Bitte manuell unter ETF/Krypto ergänzen.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Save button
            if (_canAutoSave)
              SizedBox(
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: 250.ms,
                  child: isSaved
                      ? _SavedChip(key: const ValueKey('saved'))
                      : _SaveButton(
                          key: const ValueKey('save'),
                          isLoading: isSaving,
                          onTap: onSave,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _confidenceColor(double v) {
    if (v >= 0.7) return const Color(0xFF4CAF82);
    if (v >= 0.4) return const Color(0xFFFFB347);
    return const Color(0xFFFF6B6B);
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? AppColors.primary(context) : null,
              fontSize: highlight ? 14 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({super.key, required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary(context);
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: primary),
                )
              : Text(
                  'Speichern',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SavedChip extends StatelessWidget {
  const _SavedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.positive(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.positive(context).withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 15, color: AppColors.positive(context)),
            const SizedBox(width: 6),
            Text(
              'Gespeichert',
              style: TextStyle(
                color: AppColors.positive(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.9, 0.9), duration: 200.ms);
  }
}
