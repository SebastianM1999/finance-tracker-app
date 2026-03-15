import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');
  static final _monthYearFormat = DateFormat('MMM yyyy', 'de_DE');

  static String format(DateTime date) => _dateFormat.format(date);

  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

  static String daysRemaining(DateTime endDate) {
    final days = endDate.difference(DateTime.now()).inDays;
    if (days < 0) return 'Abgelaufen';
    if (days == 0) return 'Heute fällig';
    if (days == 1) return 'Morgen fällig';
    return 'Noch $days Tage';
  }

  static int daysRemainingInt(DateTime endDate) =>
      endDate.difference(DateTime.now()).inDays;
}
