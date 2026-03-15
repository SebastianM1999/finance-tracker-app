class NumberUtils {
  NumberUtils._();

  static double calcPnlAbsolute(double shares, double buyPrice, double currentPrice) {
    return (shares * currentPrice) - (shares * buyPrice);
  }

  static double calcPnlPercent(double buyPrice, double currentPrice) {
    if (buyPrice == 0) return 0;
    return ((currentPrice - buyPrice) / buyPrice) * 100;
  }

  static double calcFestgeldPayout(double amount, double rate, int months) {
    return amount + (amount * (rate / 100) * (months / 12));
  }

  static double calcFestgeldProgress(DateTime startDate, DateTime endDate) {
    final total = endDate.difference(startDate).inDays;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().difference(startDate).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
