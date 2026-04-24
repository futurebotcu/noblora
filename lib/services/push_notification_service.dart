import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';

/// Top-level handler for background messages (must be top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[push] Background message: ${message.messageId}');
}

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Callback for when user taps a notification. Set by the app's navigator.
  static void Function(Map<String, dynamic> data)? onNotificationTapped;

  static const _androidChannel = AndroidNotificationChannel(
    'noblara_messages',
    'Messages',
    description: 'Chat messages and activity notifications',
    importance: Importance.high,
  );

  /// Initialize Firebase Messaging + local notifications.
  /// Returns false if Firebase is not configured (placeholder keys).
  static Future<bool> initialize() async {
    if (_initialized || isMockMode) return false;
    try {
      // Request permission (Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] Permission denied');
        return false;
      }

      // Setup local notifications for foreground display
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            try {
              final data = jsonDecode(response.payload!) as Map<String, dynamic>;
              onNotificationTapped?.call(data);
            } catch (e) {
              debugPrint('[push] payload parse failed: $e');
            }
          }
        },
      );

      // Create notification channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      // Foreground messages → show local notification
      FirebaseMessaging.onMessage.listen(_handleForeground);

      // Background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // Tapped notification (app was terminated or background)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        onNotificationTapped?.call(message.data);
      });

      // Check if app was opened from a terminated-state notification
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        onNotificationTapped?.call(initial.data);
      }

      _initialized = true;
      debugPrint('[push] Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[push] Init failed (Firebase not configured?): $e');
      return false;
    }
  }

  /// Get current FCM token and register it in Supabase.
  static Future<void> registerToken() async {
    if (!_initialized || isMockMode) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _saveToken(token);

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('[push] Token registration failed: $e');
    }
  }

  /// Save/update FCM token in Supabase push_tokens table.
  static Future<void> _saveToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('push_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
      debugPrint('[push] Token saved');
    } catch (e) {
      debugPrint('[push] Token save failed: $e');
    }
  }

  /// Remove all tokens for current user (call on logout).
  static Future<void> unregisterTokens() async {
    if (isMockMode) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('push_tokens')
          .delete()
          .eq('user_id', userId);
      debugPrint('[push] Tokens cleared');
    } catch (e) {
      debugPrint('[push] Token cleanup failed: $e');
    }
  }

  /// Show a local notification when a message arrives while app is in foreground.
  static void _handleForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
