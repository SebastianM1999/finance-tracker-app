class AppConstants {
  AppConstants._();

  // Spacing
  static const double spacingXs = 8.0;
  static const double spacingSm = 12.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 20.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  // Bottom nav
  static const double bottomNavHeight = 64.0;

  // Card padding
  static const double cardPadding = 20.0;

  // Firestore collections
  static const String colGiro = 'giro_accounts';
  static const String colFestgeld = 'festgeld';
  static const String colEtfStocks = 'etf_stocks';
  static const String colCrypto = 'crypto';
  static const String colPhysical = 'physical_assets';
  static const String colSchulden = 'schulden';
  static const String colNetWorthHistory = 'net_worth_history';

  // Notification channel
  static const String notifChannelId = 'festgeld_maturity';
  static const String notifChannelName = 'Festgeld Fälligkeiten';

  // Festgeld notification days
  static const List<int> festgeldNotifDays = [30, 7, 1, 0];
}
