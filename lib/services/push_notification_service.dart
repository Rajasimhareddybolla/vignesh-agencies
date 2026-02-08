import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
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
          '@drawable/ic_notification',
        ); // Use custom notification icon

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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If `onMessage` is triggered with a notification, construct our own
      // local notification to show it as a heads-up display.
      if (notification != null && android != null) {
        // Try to load notification image if available
        StyleInformation? styleInfo;
        final imageUrl =
            notification.android?.imageUrl ??
            message.data['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            final response = await http.get(Uri.parse(imageUrl));
            if (response.statusCode == 200) {
              final Uint8List imageBytes = response.bodyBytes;
              final bigPicture = ByteArrayAndroidBitmap(imageBytes);
              styleInfo = BigPictureStyleInformation(
                bigPicture,
                contentTitle: notification.title,
                summaryText: notification.body,
              );
            }
          } catch (e) {
            debugPrint('Error loading notification image: $e');
          }
        }

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
              icon: '@drawable/ic_notification',
              styleInformation: styleInfo,
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
  /// Subscribe/Unsubscribe to Admin Notifications
  Future<void> updateAdminSubscription({required bool isAdmin}) async {
    if (kIsWeb) return;

    try {
      if (isAdmin) {
        await _firebaseMessaging.subscribeToTopic('admin_notifications');
        debugPrint('Subscribed to admin_notifications');
      } else {
        await _firebaseMessaging.unsubscribeFromTopic('admin_notifications');
        debugPrint('Unsubscribed from admin_notifications');
      }
    } catch (e) {
      debugPrint('Error updating admin subscription: $e');
    }
  }

  /// Send notification to Admins for a New Order
  // Note: This relies on the client having permission to post to FCM or using a Cloud Function.
  // Since we are frontend-only, we'll try to use a Cloud Function HTTP trigger OR
  // Direct FCM if legacy server key is used (Not recommended but common in MVP).
  // BETTER: Write a document to a 'notifications_queue' collection and let a Cloud Function handle it.
  // BUT: Per user request "give notification saying to admin device not in the app only".
  // Assuming we CANNOT add Cloud Functions easily right now, we will simulate this by
  // writing to a special collection that the Admin app LISTENS to and shows a local notification?
  // NO, user said "not in the app only" -> meaning PUSH notification.
  // Implementation: We will use the `http` package to call FCM legacy API if Server Key is available,
  // OR we assume a Cloud Function exists.
  // PROPOSAL: I will add the method signature, but for now we might need to rely on
  // the backend to actually trigger this.
  // TEMPORARY SOLUTION: If we don't have backend, we can't send PUSH from client securely.
  // However, I will implement the *subscription* part so Admin is ready to receive.
  // And I will add a method that *would* call the API.
  Future<void> sendAdminOrderNotification(String orderId, String userName) async {
    // This function would ideally call a Cloud Function
    // await http.post(Uri.parse('YOUR_CLOUD_FUNCTION_URL'), body: ...);
    debugPrint('Sending admin notification for Order $orderId by $userName');
  }
}
