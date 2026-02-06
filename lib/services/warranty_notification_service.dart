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

  // Phase 3: Multiple reminder points
  static const List<int> _reminderDays = [30, 7, 3, 1];

  /// Initialize the notification service with timezone support
  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

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
      // Skip if warranty already expired
      if (!appliance.isUnderWarranty) {
        continue;
      }

      // Skip if status is not active
      if (appliance.status != ProductStatus.active) {
        continue;
      }

      // Schedule notifications for each reminder day
      for (final days in _reminderDays) {
        final notificationKey = '${appliance.id}_$days';

        // Skip if already scheduled
        if (scheduledIds.contains(notificationKey)) {
          continue;
        }

        // Calculate notification date
        final notificationDate = appliance.warrantyEndDate.subtract(
          Duration(days: days),
        );

        // Skip if notification date is in the past
        if (notificationDate.isBefore(DateTime.now())) {
          continue;
        }

        final (title, body) = _getNotificationContent(
          days,
          appliance.productName,
        );

        await _scheduleNotification(
          id: notificationKey.hashCode,
          title: title,
          body: body,
          scheduledDate: notificationDate,
          payload: appliance.id,
        );

        // Mark as scheduled
        scheduledIds.add(notificationKey);
      }
    }

    await prefs.setStringList(_scheduledNotificationsKey, scheduledIds);
  }

  /// Get notification content based on days remaining
  static (String, String) _getNotificationContent(
    int daysRemaining,
    String productName,
  ) {
    switch (daysRemaining) {
      case 30:
        return (
          'Warranty Reminder: $productName',
          'Your warranty expires in 30 days. Schedule a service check if needed.',
        );
      case 7:
        return (
          'Warranty Expiring Soon!',
          'Only 7 days left on your $productName warranty. Consider scheduling a service.',
        );
      case 3:
        return (
          '⚠️ Warranty Alert: $productName',
          'Your warranty expires in 3 days! Don\'t miss out on free service coverage.',
        );
      case 1:
        return (
          '🚨 Last Day: Warranty Expiring Tomorrow!',
          'Your $productName warranty expires tomorrow. Request service now if needed!',
        );
      default:
        return (
          'Warranty Reminder',
          'Your $productName warranty expires in $daysRemaining days.',
        );
    }
  }

  /// Get appliances with warranties expiring soon (Phase 3 - for UI alerts)
  static List<WarrantyAlert> getWarrantyAlerts(
    List<UserApplianceModel> appliances,
  ) {
    final alerts = <WarrantyAlert>[];
    final now = DateTime.now();

    for (final appliance in appliances) {
      if (appliance.status != ProductStatus.active) continue;

      final daysRemaining = appliance.warrantyEndDate.difference(now).inDays;

      if (daysRemaining < 0) {
        // Expired
        alerts.add(
          WarrantyAlert(
            appliance: appliance,
            daysRemaining: daysRemaining,
            alertType: WarrantyAlertType.expired,
          ),
        );
      } else if (daysRemaining <= 3) {
        // Critical
        alerts.add(
          WarrantyAlert(
            appliance: appliance,
            daysRemaining: daysRemaining,
            alertType: WarrantyAlertType.critical,
          ),
        );
      } else if (daysRemaining <= 7) {
        // Warning
        alerts.add(
          WarrantyAlert(
            appliance: appliance,
            daysRemaining: daysRemaining,
            alertType: WarrantyAlertType.warning,
          ),
        );
      } else if (daysRemaining <= 30) {
        // Info
        alerts.add(
          WarrantyAlert(
            appliance: appliance,
            daysRemaining: daysRemaining,
            alertType: WarrantyAlertType.info,
          ),
        );
      }
    }

    // Sort by urgency (most urgent first)
    alerts.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return alerts;
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
        icon: '@drawable/ic_notification',
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

    // Cancel all reminder notifications for this appliance
    for (final days in _reminderDays) {
      await _notifications.cancel('${applianceId}_$days'.hashCode);
    }

    final prefs = await SharedPreferences.getInstance();
    final scheduledIds = prefs.getStringList(_scheduledNotificationsKey) ?? [];
    scheduledIds.removeWhere((id) => id.startsWith(applianceId));
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

/// Warranty alert types for UI display
enum WarrantyAlertType {
  info, // 30 days or less
  warning, // 7 days or less
  critical, // 3 days or less
  expired, // Already expired
}

/// Warranty alert model for UI
class WarrantyAlert {
  final UserApplianceModel appliance;
  final int daysRemaining;
  final WarrantyAlertType alertType;

  const WarrantyAlert({
    required this.appliance,
    required this.daysRemaining,
    required this.alertType,
  });

  String get message {
    if (daysRemaining < 0) {
      return 'Warranty expired ${-daysRemaining} days ago';
    } else if (daysRemaining == 0) {
      return 'Warranty expires today!';
    } else if (daysRemaining == 1) {
      return 'Warranty expires tomorrow!';
    } else {
      return 'Warranty expires in $daysRemaining days';
    }
  }
}
