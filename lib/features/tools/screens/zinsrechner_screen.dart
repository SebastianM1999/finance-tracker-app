import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import 'tools_widgets.dart';

class ZinsrechnerScreen extends StatefulWidget {
  const ZinsrechnerScreen({super.key, this.scrollController});
  final ScrollController? scrollController;

  @override
  State<ZinsrechnerScreen> createState() => _ZinsrechnerScreenState();
}

class _ZinsrechnerScreenState extends State<ZinsrechnerScreen> {
  final _betragCtrl = TextEditingController(text: '10000');
  final _zinsCtrl = TextEditingController(text: '4,0');
  final _laufzeitCtrl = TextEditingController(text: '5');
  int _intervalN = 12; // 1 = jährlich, 12 = monatlich, 365 = täglich

  double _anfang = 10000;
  double _zins = 4.0;
  int _laufzeit = 5;

  double get _endkapital {
    final r = _zins / 100;
    return _anfang * pow(1 + r / _intervalN, _intervalN * _laufzeit);
  }

  double get _zinsen => _endkapital - _anfang;

  void _parse() {
    setState(() {
      _anfang = _pd(_betragCtrl.text) ?? _anfang;
      _zins = _pd(_zinsCtrl.text) ?? _zins;
      _laufzeit = int.tryParse(_laufzeitCtrl.text.trim()) ?? _laufzeit;
    });
  }

  double? _pd(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _betragCtrl.dispose();
    _zinsCtrl.dispose();
    _laufzeitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Zinsrechner',
              style: TextStyle(
                  color: onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Zinseszins-Berechnung',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 24),

          ToolInputField(
            label: 'Anfangsbetrag (€)',
            controller: _betragCtrl,
            onChanged: (_) => _parse(),
            inputType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          ToolInputField(
            label: 'Zinssatz p.a. (%)',
            controller: _zinsCtrl,
            onChanged: (_) => _parse(),
            inputType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          ToolInputField(
            label: 'Laufzeit (Jahre)',
            controller: _laufzeitCtrl,
            onChanged: (_) => _parse(),
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 14),

          Text('Zinsintervall',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              ToolIntervalChip(
                  label: 'Täglich',
                  selected: _intervalN == 365,
                  onTap: () => setState(() => _intervalN = 365)),
              const SizedBox(width: 8),
              ToolIntervalChip(
                  label: 'Monatlich',
                  selected: _intervalN == 12,
                  onTap: () => setState(() => _intervalN = 12)),
              const SizedBox(width: 8),
              ToolIntervalChip(
                  label: 'Jährlich',
                  selected: _intervalN == 1,
                  onTap: () => setState(() => _intervalN = 1)),
            ],
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ergebnis',
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(_endkapital),
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Endkapital nach $_laufzeit ${_laufzeit == 1 ? 'Jahr' : 'Jahren'}',
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                ToolResultRow(
                  label: 'Einzahlung',
                  value: CurrencyFormatter.format(_anfang),
                  color: AppColors.textSecondary(context),
                ),
                const SizedBox(height: 8),
                ToolResultRow(
                  label: 'Zinserträge',
                  value: '+${CurrencyFormatter.format(_zinsen)}',
                  color: AppColors.positive(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
