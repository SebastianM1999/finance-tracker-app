import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Handles FCM token storage and foreground message routing.
class FcmService {
  FcmService._();

  static bool _initialized = false;

  /// Call once when a user logs in. Stores the FCM token to Firestore
  /// so the Cloud Function can send push notifications.
  static Future<void> initializeForUser(String uid) async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS / Android 13+)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Store current token
    final token = await messaging.getToken();
    if (token != null) await _saveToken(uid, token);

    // Refresh token when it rotates
    messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));

    // Show local notification for messages received while app is in foreground
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title != null && body != null) {
        NotificationService.instance.showWatchlistAlertRaw(
          title: title,
          body: body,
        );
      }
    });
  }

  static void reset() => _initialized = false;

  static Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}
