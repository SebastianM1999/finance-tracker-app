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

  static String format(double amount, {String symbol = '€'}) {
    if (symbol != '€') {
      return NumberFormat.currency(
        locale: 'de_DE',
        symbol: symbol,
        decimalDigits: 2,
      ).format(amount);
    }
    return _eurFormat.format(amount);
  }

  static String formatCompact(double amount) => _compactFormat.format(amount);

  static String formatPnl(double amount) {
    final prefix = amount >= 0 ? '+' : '';
    return '$prefix${format(amount)}';
  }

  static String formatPercent(double percent) {
    final prefix = percent >= 0 ? '+' : '';
    return '$prefix${percent.toStringAsFixed(2)} %';
  }
}
