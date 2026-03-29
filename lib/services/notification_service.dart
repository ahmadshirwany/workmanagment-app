import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _reminderIntervalKey = 'reminder_interval';
  static const String _customIntervalKey = 'custom_interval';

  bool get isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> initialize() async {
    if (kIsWeb || !isMobilePlatform) {
      // Web or desktop platform - notifications not fully supported
      return;
    }

    try {
      tzData.initializeTimeZones();
      // Use device's local timezone instead of UTC
      final String timeZoneName = await _getLocalTimeZone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
      },
    );

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      // Request exact alarm permission for Android 12+
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }
  }

  Future<String> _getLocalTimeZone() async {
    try {
      // Get the device's timezone offset and find matching timezone
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      
      // Common timezone mappings based on offset
      final timezoneMap = <int, String>{
        330: 'Asia/Kolkata',      // UTC+5:30
        0: 'UTC',                 // UTC
        60: 'Europe/Paris',       // UTC+1
        120: 'Europe/Helsinki',   // UTC+2
        180: 'Europe/Moscow',     // UTC+3
        240: 'Asia/Dubai',        // UTC+4
        300: 'Asia/Karachi',      // UTC+5
        360: 'Asia/Dhaka',        // UTC+6
        420: 'Asia/Bangkok',      // UTC+7
        480: 'Asia/Singapore',    // UTC+8
        540: 'Asia/Tokyo',        // UTC+9
        600: 'Australia/Sydney',  // UTC+10
        -300: 'America/New_York', // UTC-5
        -360: 'America/Chicago',  // UTC-6
        -420: 'America/Denver',   // UTC-7
        -480: 'America/Los_Angeles', // UTC-8
      };
      
      final offsetMinutes = offset.inMinutes;
      return timezoneMap[offsetMinutes] ?? 'UTC';
    } catch (e) {
      return 'UTC';
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);

    if (enabled) {
      await scheduleNotifications();
    } else {
      await cancelAllNotifications();
    }
  }

  Future<int> getReminderInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_reminderIntervalKey) ?? 4; // Default 4 hours
  }

  Future<void> setReminderInterval(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderIntervalKey, hours);

    if (await areNotificationsEnabled()) {
      await scheduleNotifications();
    }
  }

  Future<int?> getCustomInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_customIntervalKey);
  }

  Future<void> setCustomInterval(int? minutes) async {
    final prefs = await SharedPreferences.getInstance();
    if (minutes != null) {
      await prefs.setInt(_customIntervalKey, minutes);
    } else {
      await prefs.remove(_customIntervalKey);
    }

    if (await areNotificationsEnabled()) {
      await scheduleNotifications();
    }
  }

  Future<void> scheduleNotifications() async {
    if (!isMobilePlatform) return;
    
    try {
      await cancelAllNotifications();

      final interval = await getReminderInterval();
      final customInterval = await getCustomInterval();

      final minutes = customInterval ?? (interval * 60);

      // Reinitialize timezone to ensure it's correct
      try {
        final String timeZoneName = await _getLocalTimeZone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // Get current time in local timezone
      final now = tz.TZDateTime.now(tz.local);
      
      print('Scheduling notifications - Current time: $now, Interval: $minutes minutes');
      
      // Schedule next 10 notifications with the specified interval
      for (int i = 0; i < 10; i++) {
        final scheduledDate = now.add(Duration(minutes: minutes * (i + 1)));
        print('Notification ${i + 1} scheduled for: $scheduledDate');
        
        await _notifications.zonedSchedule(
          i, // Unique ID for each notification
          'Discipline Tracker Reminder',
          'Don\'t forget to update your daily tasks and habits! 💪',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminder',
              'Daily Reminders',
              channelDescription: 'Reminders to update your daily tasks',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      
      // Verify that notifications were scheduled
      final pending = await _notifications.pendingNotificationRequests();
      print('Scheduled ${pending.length} notifications');
    } catch (e) {
      print('Error scheduling notifications: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!isMobilePlatform) return;
    await _notifications.cancelAll();
  }

  Future<void> showTestNotification() async {
    if (!isMobilePlatform) return;
    await _notifications.show(
      999,
      'Test Notification',
      'Your notifications are working! 🎉',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notification channel',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showWorkTimeAlert() async {
    if (!isMobilePlatform) return;
    await _notifications.show(
      100,
      '⏰ Time Check',
      'You\'ve been working for 45+ minutes! Consider taking a short break.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'work_time_alerts',
          'Work Time Alerts',
          channelDescription: 'Alerts for long work sessions',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification_sound.aiff',
        ),
      ),
    );
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!isMobilePlatform) return [];
    return await _notifications.pendingNotificationRequests();
  }
}
