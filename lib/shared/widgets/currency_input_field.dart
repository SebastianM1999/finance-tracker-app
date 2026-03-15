import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CurrencyInputField extends StatefulWidget {
  const CurrencyInputField({
    super.key,
    required this.label,
    this.initialValue,
    required this.onChanged,
    this.suffix = '€',
  });

  final String label;
  final double? initialValue;
  final ValueChanged<double> onChanged;
  final String suffix;

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
        suffixText: widget.suffix,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Pflichtfeld';
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        if (parsed == null) return 'Ungültiger Betrag';
        return null;
      },
      onChanged: (v) {
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        if (parsed != null) widget.onChanged(parsed);
      },
    );
  }
}
