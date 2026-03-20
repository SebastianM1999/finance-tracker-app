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

  /// Returns a human-readable "price age" string, e.g. "vor 3 Min." or "vor 2 Std."
  static String priceAge(DateTime? lastUpdate) {
    if (lastUpdate == null) return '';
    final diff = DateTime.now().difference(lastUpdate);
    if (diff.inSeconds < 60) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    return 'vor ${diff.inDays} ${diff.inDays == 1 ? 'Tag' : 'Tagen'}';
  }
}
