import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _eurFormat = NumberFormat.currency(
    locale: 'de_DE',
    symbol: '€',
    decimalDigits: 2,
  );

  static final _compactFormat = NumberFormat.compactCurrency(
    locale: 'de_DE',
    symbol: '€',
    decimalDigits: 1,
  );

  // Removes any space/non-breaking space before the € symbol
  static String _stripEurSpace(String s) =>
      s.replaceAll(RegExp(r'[\u00A0\s]+€'), '€');

  static String format(double amount, {String symbol = '€'}) {
    if (symbol != '€') {
      return NumberFormat.currency(
        locale: 'de_DE',
        symbol: symbol,
        decimalDigits: 2,
      ).format(amount).replaceAll(RegExp(r'[\u00A0\s]+' + RegExp.escape(symbol)), symbol);
    }
    return _stripEurSpace(_eurFormat.format(amount));
  }

  static String formatCompact(double amount) =>
      _stripEurSpace(_compactFormat.format(amount));

  static String formatPnl(double amount) {
    final prefix = amount >= 0 ? '+' : '';
    return '$prefix${format(amount)}';
  }

  static String formatPercent(double percent) {
    final prefix = percent >= 0 ? '+' : '';
    return '$prefix${percent.toStringAsFixed(2)}%';
  }

  /// Smart crypto amount formatting — like Coinbase/Binance:
  /// ≥1 → 4 decimals, ≥0.01 → 6 decimals, <0.01 → 8 decimals
  static String formatCryptoAmount(double amount) {
    if (amount >= 1) return _fmt(amount, 4);
    if (amount >= 0.01) return _fmt(amount, 6);
    return _fmt(amount, 8);
  }

  static String _fmt(double v, int decimals) {
    final formatted = NumberFormat('#,##0.${'0' * decimals}', 'de_DE').format(v);
    if (!formatted.contains(',')) return formatted;
    final stripped = formatted.replaceAll(RegExp(r',?0+$'), '');
    return stripped.isEmpty || stripped == '-' ? '0' : stripped;
  }
}
