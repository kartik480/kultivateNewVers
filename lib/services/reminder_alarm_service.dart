import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderAlarmService {
  ReminderAlarmService._();

  static final ReminderAlarmService instance = ReminderAlarmService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _channelId = 'manual_reminders_channel';
  static const String _channelName = 'Manual reminders';
  static const String _channelDescription = 'Daily alarms for habit reminders';

  Future<bool> _requestPlatformPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notifGranted = await android?.requestNotificationsPermission();
      final exactGranted = await android?.requestExactAlarmsPermission();
      return (notifGranted ?? true) && (exactGranted ?? true);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? true;
    }
    return true;
  }

  Future<bool> requestReminderPermissions() async {
    final ok = await ensureInitialized();
    if (!ok) return false;
    try {
      return await _requestPlatformPermissions();
    } catch (e, st) {
      debugPrint('reminder permission request: $e\n$st');
      return false;
    }
  }

  Future<bool> ensureInitialized() async {
    if (_isInitialized) return true;
    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(settings: initSettings);

      await _requestPlatformPermissions();

      _isInitialized = true;
      return true;
    } catch (e, st) {
      debugPrint('reminder alarm init: $e\n$st');
      return false;
    }
  }

  Future<bool> scheduleDailyReminder({
    required int alarmId,
    required String title,
    required TimeOfDay time,
    String? body,
  }) async {
    final ok = await ensureInitialized();
    if (!ok) return false;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var fireAt = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!fireAt.isAfter(now)) {
        fireAt = fireAt.add(const Duration(days: 1));
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );

      await _plugin.zonedSchedule(
        id: alarmId,
        title: 'Reminder: $title',
        body: body?.trim().isNotEmpty == true
            ? body!.trim()
            : 'Time to complete "$title".',
        scheduledDate: fireAt,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'manual_reminder',
      );
      return true;
    } catch (e, st) {
      debugPrint('reminder alarm schedule: $e\n$st');
      return false;
    }
  }

  Future<void> cancelReminder(int alarmId) async {
    final ok = await ensureInitialized();
    if (!ok) return;
    await _plugin.cancel(id: alarmId);
  }

  Future<void> cancelAll() async {
    final ok = await ensureInitialized();
    if (!ok) return;
    await _plugin.cancelAll();
  }
}
