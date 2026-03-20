import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CurrencyInputField extends StatefulWidget {
  const CurrencyInputField({
    super.key,
    required this.label,
    this.initialValue,
    required this.onChanged,
    this.suffix = '€',
    this.loading = false,
  });

  final String label;
  final double? initialValue;
  final ValueChanged<double> onChanged;
  final String suffix;
  final bool loading;

  @override
  State<CurrencyInputField> createState() => _CurrencyInputFieldState();
}

class _CurrencyInputFieldState extends State<CurrencyInputField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialValue != null
          ? widget.initialValue!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void didUpdateWidget(CurrencyInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != null) {
      // Only overwrite if the current text doesn't already represent the new
      // value — prevents clobbering in-progress user input (e.g. "5" → "5.00"
      // while the user is still typing "500").
      final currentParsed =
          double.tryParse(_ctrl.text.replaceAll(',', '.'));
      if (currentParsed == widget.initialValue) return;
      _ctrl.text = widget.initialValue!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.loading ? null : widget.suffix,
        suffixIcon: widget.loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      readOnly: widget.loading,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Pflichtfeld';
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        if (parsed == null) return 'Ungültiger Betrag';
        if (parsed <= 0) return 'Betrag muss größer als 0 sein';
        return null;
      },
      onChanged: (v) {
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        if (parsed != null) widget.onChanged(parsed);
      },
    );
  }
}
