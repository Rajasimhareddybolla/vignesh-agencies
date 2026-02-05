import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Key for the notification channel
const String kNotificationChannelId = 'high_importance_channel';
const String kNotificationChannelName = 'High Importance Notifications';

// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to access other Firebase services in the background,
  // you must initialize Firebase here (e.g. Firebase.initializeApp()).
  // But for simple display, this might not be strictly necessary depending on setup.
  debugPrint('Handling a background message ${message.messageId}');
}

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Request permissions (especially for iOS)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Set foreground presentation options (iOS)
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Initialize Local Notifications (for Android Foreground)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ); // Verify icon name

    // Note: iOS initialization is handled differently, often defaults work with FCM plugin,
    // but explicit setup for local notifications needed for foreground heads-up on Android often.
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle tapping a local notification
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );

    // 4. Create Android Notification Channel
    // This is required for high priority notifications on Android 8.0+
    final AndroidNotificationChannel channel = const AndroidNotificationChannel(
      kNotificationChannelId,
      kNotificationChannelName,
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // 5. Register Background Handler
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }

    // 6. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If `onMessage` is triggered with a notification, construct our own
      // local notification to show it as a heads-up display.
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              kNotificationChannelId,
              kNotificationChannelName,
              channelDescription:
                  'This channel is used for important notifications.',
              icon: '@mipmap/ic_launcher', // Maintain consistent icon
              // other properties...
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 7. Handle Background/Terminated State Tap
    // When the app is opened from a notification (Terminated state)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint(
          'App opened from terminated state by notification: ${message.messageId}',
        );
        // Navigate to specific screen if needed
      }
    });

    // When the app is opened from background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        'App opened from background state by notification: ${message.messageId}',
      );
      // Navigate to specific screen if needed
    });

    // Get the token for debugging/sending test messages
    // Note: On web, getToken() might require a vapidKey
    try {
      final token = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $token');
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Update subscription to promo notifications based on user role
  Future<void> updatePromoSubscription({required bool isUser}) async {
    if (kIsWeb) return;

    try {
      if (isUser) {
        await _firebaseMessaging.subscribeToTopic('promo_notifications');
        debugPrint('Subscribed to promo_notifications');
      } else {
        await _firebaseMessaging.unsubscribeFromTopic('promo_notifications');
        debugPrint('Unsubscribed from promo_notifications');
      }
    } catch (e) {
      debugPrint('Error updating promo subscription: $e');
    }
  }
}
