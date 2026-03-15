import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  /// Call once from main() before runApp().
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

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
              importance: Importance.high,
              priority: Priority.high,
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

  /// Show an immediate notification (no scheduling) to verify the pipeline works.
  Future<void> showImmediateTestNotification() async {
    if (kIsWeb) return;
    await _plugin.show(
      888888,
      '🔔 Test-Benachrichtigung',
      'Push-Notifications funktionieren!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
    // Also fire a delayed one via Future.delayed (bypasses AlarmManager)
    Future.delayed(const Duration(seconds: 10), () {
      _plugin.show(
        777777,
        '🔔 Test (Future.delayed)',
        'In-process delayed notification!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  /// Schedule a test notification firing in 10 seconds.
  /// Falls back to inexact mode if exact alarm permission is not granted.
  Future<void> scheduleTestNotification() async {
    if (kIsWeb) return;
    final now = DateTime.now();
    var triggerTime = DateTime(now.year, now.month, now.day, 0, 1);
    if (!triggerTime.isAfter(now)) {
      triggerTime = triggerTime.add(const Duration(days: 1));
    }
    final exact = await canScheduleExact();
    final tzTime = _toTZDateTime(triggerTime);
    debugPrint('[Notif] canScheduleExact=$exact');
    debugPrint('[Notif] now=${DateTime.now()}, triggerTime=$triggerTime, tzTime=$tzTime');
    try {
      await _plugin.zonedSchedule(
        999999,
        '🔔 Test (geplant)',
        'Geplante Benachrichtigung funktioniert!',
        tzTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[Notif] zonedSchedule succeeded');
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('[Notif] pending count=${pending.length}, ids=${pending.map((p) => p.id).toList()}');
    } catch (e, st) {
      debugPrint('[Notif] zonedSchedule ERROR: $e\n$st');
    }
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

  tz.TZDateTime _toTZDateTime(DateTime dt) {
    // Use millisecondsSinceEpoch to avoid tz.local defaulting to UTC
    // when setLocalLocation() was never called.
    return tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, dt.millisecondsSinceEpoch);
  }
}
