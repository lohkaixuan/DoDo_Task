// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  NotificationService() {
    tz.initializeTimeZones();
  }

  Future<void> init({Future<void> Function(String payload)? onSelectPayload}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const init = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload;
        if (onSelectPayload != null && payload != null) {
          await onSelectPayload(payload);
        }
      },
    );
  }

  // ---------- Common details ----------
  NotificationDetails _defaultDetails() {
    const android = AndroidNotificationDetails(
      'tasks_channel',
      'Tasks',
      channelDescription: 'Task reminders and focus nudges',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }

  // Stable hash to turn (taskId|key) into an int ID
  int _hash(String s) {
    int h = 0;
    for (var i = 0; i < s.length; i++) {
      h = 0x1fffffff & (h + s.codeUnitAt(i));
      h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
      h ^= (h >> 6);
    }
    h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
    h ^= (h >> 11);
    h = 0x1fffffff & (h + ((0x00003fff & h) << 15));
    return h & 0x7fffffff;
  }

  // ---------- One-shot ----------
  Future<void> scheduleOneShot(
    String taskId,
    String key,
    DateTime when,
    String body, {
    String? payload,
  }) async {
    final id = _hash('$taskId|$key');
    final tzz = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      'Reminder',
      body,
      tzz,
      _defaultDetails(),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
      payload: payload ?? taskId,
    );
  }

  // ---------- Hourly repeating ----------
  // (If you need "every 2 hours", schedule your own rolling one-shots.)
  Future<void> scheduleHourly(
    String taskId,
    String key,
    int everyNHours,
    String body, {
    String? payload,
  }) async {
    final id = _hash('$taskId|hourly|$key');
    await _plugin.periodicallyShow(
      id,
      'Reminder',
      body,
      RepeatInterval.hourly,
      _defaultDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload ?? taskId,
    );
  }

  // ---------- Daily at a time ----------
  Future<void> scheduleDaily(
    String taskId,
    String key,
    String body, {
    int hour = 9,
    int minute = 0,
    String? payload,
  }) async {
    final id = _hash('$taskId|daily|$key');
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id,
      'Reminder',
      body,
      next,
      _defaultDetails(),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload ?? taskId,
    );
  }

  // ---------- Ongoing "Focus" sticky ----------
  Future<void> showFocusOngoing({
    required int id,
    required String title,
    required int minutesLeft,
  }) async {
    const android = AndroidNotificationDetails(
      'focus_timer',
      'Focus timer',
      channelDescription: 'Shows the current focus session',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      visibility: NotificationVisibility.public,
    );
    await _plugin.show(
      id,
      'Focusing: $title',
      'Time left: ${minutesLeft}m',
      const NotificationDetails(android: android),
    );
  }

  Future<void> cancelId(int id) async => _plugin.cancel(id);

  // Simple strategy: cancel all notifications for a task (and generally).
  // If you want fine-grained cancel per (taskId,key), store their IDs and cancel them by id.
  Future<void> cancelForTask(String taskId) async {
    await _plugin.cancelAll();
  }
}
