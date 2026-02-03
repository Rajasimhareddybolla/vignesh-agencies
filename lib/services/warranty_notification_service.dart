import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_appliance_model.dart';

/// Service to handle local notifications for warranty expiry reminders
class WarrantyNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _scheduledNotificationsKey =
      'scheduled_warranty_notifications';
  static const int _daysBeforeExpiry = 30;

  /// Initialize the notification service with timezone support
  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap - could navigate to appliance detail
      },
    );

    // Create notification channel for warranty reminders
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'warranty_reminders',
      'Warranty Reminders',
      description: 'Notifications for warranty expiry reminders',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Schedule warranty expiry notifications for user's appliances
  static Future<void> scheduleWarrantyNotifications(
    List<UserApplianceModel> appliances,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledIds = prefs.getStringList(_scheduledNotificationsKey) ?? [];

    for (final appliance in appliances) {
      // Skip if already scheduled or warranty already expired
      if (scheduledIds.contains(appliance.id) || !appliance.isUnderWarranty) {
        continue;
      }

      // Skip if status is not active
      if (appliance.status != ProductStatus.active) {
        continue;
      }

      // Calculate notification date (30 days before expiry)
      final notificationDate = appliance.warrantyEndDate.subtract(
        const Duration(days: _daysBeforeExpiry),
      );

      // Skip if notification date is in the past
      if (notificationDate.isBefore(DateTime.now())) {
        continue;
      }

      await _scheduleNotification(
        id: appliance.id.hashCode,
        title: 'Warranty Expiring Soon!',
        body:
            'Your ${appliance.productName} warranty expires in $_daysBeforeExpiry days. '
            'Schedule a service check if needed.',
        scheduledDate: notificationDate,
        payload: appliance.id,
      );

      // Mark as scheduled
      scheduledIds.add(appliance.id);
    }

    await prefs.setStringList(_scheduledNotificationsKey, scheduledIds);
  }

  /// Schedule a single notification
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'warranty_reminders',
        'Warranty Reminders',
        channelDescription: 'Notifications for warranty expiry reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      // Try exact alarm first (preferred for precise warranty notifications)
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
        payload: payload,
      );
    } catch (e) {
      // Fallback to inexact mode if exact alarms aren't permitted (Android 12+)
      if (e.toString().contains('exact_alarms_not_permitted')) {
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledTZDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: null,
          payload: payload,
        );
      } else {
        // Log other errors but don't crash the app
        print('Failed to schedule notification: $e');
      }
    }
  }

  /// Cancel all scheduled warranty notifications for a user
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduledNotificationsKey);
  }

  /// Cancel notification for a specific appliance
  static Future<void> cancelNotification(String applianceId) async {
    await _notifications.cancel(applianceId.hashCode);

    final prefs = await SharedPreferences.getInstance();
    final scheduledIds = prefs.getStringList(_scheduledNotificationsKey) ?? [];
    scheduledIds.remove(applianceId);
    await prefs.setStringList(_scheduledNotificationsKey, scheduledIds);
  }

  /// Check and schedule notifications when user logs in or app starts
  static Future<void> checkAndScheduleNotifications(
    List<UserApplianceModel> appliances,
  ) async {
    // Only schedule for active warranties
    final activeAppliances =
        appliances
            .where((a) => a.status == ProductStatus.active && a.isUnderWarranty)
            .toList();

    await scheduleWarrantyNotifications(activeAppliances);
  }
}
