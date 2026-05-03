import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Maps OS-specific timezone labels to IANA ids when [tz.getLocation] fails.
String _ianaAlias(String id) {
  const aliases = <String, String>{
    'India Standard Time': 'Asia/Kolkata',
    'China Standard Time': 'Asia/Shanghai',
    'Singapore Standard Time': 'Asia/Singapore',
    'GMT Standard Time': 'Europe/London',
    'Romance Standard Time': 'Europe/Paris',
    'W. Europe Standard Time': 'Europe/Berlin',
    'Eastern Standard Time': 'America/New_York',
    'Central Standard Time': 'America/Chicago',
    'Pacific Standard Time': 'America/Los_Angeles',
  };
  return aliases[id] ?? id;
}

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
      if (notifGranted == false) return false;
      // Exact alarms improve timing; scheduling still works via inexact fallback if denied.
      await android?.requestExactAlarmsPermission();
      final enabled = await android?.areNotificationsEnabled();
      return enabled != false;
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

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications();
    if (canExact == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
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
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        final id = timezoneInfo.identifier;
        try {
          tz.setLocalLocation(tz.getLocation(id));
        } catch (_) {
          try {
            tz.setLocalLocation(tz.getLocation(_ianaAlias(id)));
          } catch (e2, st2) {
            debugPrint('reminder tz unknown zone $id: $e2\n$st2');
            tz.setLocalLocation(tz.UTC);
          }
        }
      } catch (e, st) {
        debugPrint('reminder FlutterTimezone failed: $e\n$st');
        tz.setLocalLocation(tz.UTC);
      }

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

  AndroidNotificationDetails _androidDetails() {
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: false,
      playSound: true,
      enableVibration: true,
    );
  }

  Future<void> _zonedSchedule({
    required int alarmId,
    required String title,
    required String body,
    required tz.TZDateTime fireAt,
    required AndroidScheduleMode androidScheduleMode,
  }) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    await _plugin.zonedSchedule(
      id: alarmId,
      title: title,
      body: body,
      scheduledDate: fireAt,
      notificationDetails: NotificationDetails(
        android: _androidDetails(),
        iOS: iosDetails,
      ),
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'manual_reminder',
    );
  }

  /// Whether Android blocked notifications for this app (POST_NOTIFICATIONS off).
  Future<bool> androidNotificationsBlocked() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final ok = await ensureInitialized();
    if (!ok) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final enabled = await android?.areNotificationsEnabled();
    return enabled == false;
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
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.requestNotificationsPermission();
        final enabled = await android?.areNotificationsEnabled();
        if (enabled == false) {
          debugPrint('ReminderAlarmService: notifications disabled');
          return false;
        }
      }

      // Use device wall clock so the instant is correct even if tz.local name
      // mismatches (Android AlarmManager uses timeZoneName for daily repeat).
      final nowWall = DateTime.now();
      var nextWall = DateTime(
        nowWall.year,
        nowWall.month,
        nowWall.day,
        time.hour,
        time.minute,
      );
      if (!nextWall.isAfter(nowWall)) {
        nextWall = nextWall.add(const Duration(days: 1));
      }
      final fireAt = tz.TZDateTime.from(nextWall, tz.local);

      final titleText = 'Reminder: $title';
      final bodyText = body?.trim().isNotEmpty == true
          ? body!.trim()
          : 'Time to complete "$title".';

      final androidMode = await _androidScheduleMode();

      try {
        await _zonedSchedule(
          alarmId: alarmId,
          title: titleText,
          body: bodyText,
          fireAt: fireAt,
          androidScheduleMode: androidMode,
        );
      } on PlatformException catch (e, st) {
        debugPrint('reminder alarm schedule: ${e.code} ${e.message}\n$st');
        if (defaultTargetPlatform == TargetPlatform.android &&
            e.code == 'exact_alarms_not_permitted') {
          await _zonedSchedule(
            alarmId: alarmId,
            title: titleText,
            body: bodyText,
            fireAt: fireAt,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } else {
          rethrow;
        }
      }
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
