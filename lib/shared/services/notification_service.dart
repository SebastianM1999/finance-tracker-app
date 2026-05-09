import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages local push notifications for Festgeld maturity reminders.
/// Scheduling happens when a Festgeld entry is created or updated.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'festgeld_maturity';
  static const _channelName = 'Festgeld Fälligkeiten';
  static const _watchlistChannelId = 'watchlist_alerts';
  static const _watchlistChannelName = 'Kurs-Benachrichtigungen';
  static const _chipRadarChannelId = 'chip_radar_alerts';
  static const _chipRadarChannelName = 'Chip Radar Alarme';

  /// Call once from main() before runApp().
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Request runtime notification permission (Android 13+ / API 33+)
    await androidPlugin?.requestNotificationsPermission();

    // Request exact alarm permission (Android 12+ / API 31+)
    // Opens "Alarms & reminders" settings page if not already granted
    await androidPlugin?.requestExactAlarmsPermission();

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Erinnerungen zu Festgeld-Fälligkeiten',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const watchlistChannel = AndroidNotificationChannel(
      _watchlistChannelId,
      _watchlistChannelName,
      description: 'Benachrichtigungen wenn dein Kursziel erreicht wird',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(watchlistChannel);

    const chipChannel = AndroidNotificationChannel(
      _chipRadarChannelId,
      _chipRadarChannelName,
      description: 'Alarme für Halbleiter-Aktien Kurssprünge',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chipChannel);

    _initialized = true;
  }

  /// Schedule maturity notifications for a Festgeld entry.
  /// Call on create and on edit.
  Future<List<int>> scheduleFestgeldNotifications({
    required String festgeldId,
    required String bankName,
    required double amount,
    required DateTime endDate,
  }) async {
    if (kIsWeb) return [];
    await cancelFestgeldNotifications(festgeldId);

    final scheduledIds = <int>[];
    final reminders = [
      (30, '⏰ Festgeld läuft bald ab', '$bankName – noch 30 Tage bis ${_fmt(endDate)}'),
      (7, '⚠️ Festgeld läuft in 7 Tagen ab', '$bankName – ${amount.toStringAsFixed(0)} €'),
      (1, '🔔 Morgen läuft dein Festgeld ab!', '$bankName – ${amount.toStringAsFixed(0)} € wird fällig'),
      (0, '✅ Festgeld ist heute fällig!', '$bankName – ${amount.toStringAsFixed(0)} € + Zinsen verfügbar'),
    ];

    for (final (days, title, body) in reminders) {
      final d = endDate.subtract(Duration(days: days));
      // Always fire at 08:00 AM on the trigger date
      final triggerDate = DateTime(d.year, d.month, d.day, 8, 0);
      if (triggerDate.isAfter(DateTime.now())) {
        final id = '${festgeldId}_$days'.hashCode;
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          _toTZDateTime(triggerDate),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.max,
              priority: Priority.max,
              category: AndroidNotificationCategory.alarm,
              largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        scheduledIds.add(id);
      }
    }

    return scheduledIds;
  }

  /// Show an immediate watchlist price alert notification.
  Future<void> showWatchlistAlert({
    required String symbol,
    required String name,
    required double currentPrice,
    required double targetPrice,
  }) async {
    if (kIsWeb) return;
    final notifEnabled = await areNotificationsEnabled();
    if (!notifEnabled) return;
    final id = 'watchlist_$symbol'.hashCode;
    final priceStr = targetPrice >= 1000
        ? '${(targetPrice / 1000).toStringAsFixed(1)}k€'
        : '${targetPrice.toStringAsFixed(2)}€';
    await _plugin.show(
      id,
      'Kursziel erreicht: $symbol',
      '$name hat dein Ziel von $priceStr erreicht!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _watchlistChannelId,
          _watchlistChannelName,
          importance: Importance.high,
          priority: Priority.high,
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Show a raw push notification (used when FCM message arrives in foreground).
  Future<void> showWatchlistAlertRaw({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    final id = title.hashCode ^ body.hashCode;
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _watchlistChannelId,
          _watchlistChannelName,
          importance: Importance.high,
          priority: Priority.high,
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Show a Chip Radar surge alert (shown when FCM message arrives in foreground).
  Future<void> showChipRadarAlert({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    final id = title.hashCode ^ body.hashCode;
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chipRadarChannelId,
          _chipRadarChannelName,
          importance: Importance.high,
          priority: Priority.high,
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Show an immediate test notification.
  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    final notifEnabled = await areNotificationsEnabled();
    if (!notifEnabled) return;
    await _plugin.show(
      888888,
      '🔔 Test-Erinnerung',
      'Benachrichtigungen funktionieren!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          importance: Importance.max,
          priority: Priority.max,
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Returns true if the user has notifications enabled for this app.
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    return await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ??
        true;
  }

  /// Opens the "Alarms & reminders" settings page so the user can grant exact alarm permission.
  Future<void> requestExactAlarmsPermission() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  /// Returns true if exact alarms are permitted on this device.
  Future<bool> canScheduleExact() async {
    if (kIsWeb) return false;
    return await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        true; // iOS / non-Android: assume yes
  }

  /// Cancel all notifications for a Festgeld entry.
  /// Call on delete and before re-scheduling on edit.
  Future<void> cancelFestgeldNotifications(String festgeldId) async {
    if (kIsWeb) return;
    for (final days in [30, 7, 1, 0]) {
      final id = '${festgeldId}_$days'.hashCode;
      await _plugin.cancel(id);
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  tz.TZDateTime _toTZDateTime(DateTime dt) =>
      tz.TZDateTime.from(dt, tz.local);
}
