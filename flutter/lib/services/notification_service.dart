// lib/services/notification_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // ✅ timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTapForeground,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  // ========= Permissions (Android 13+) =========

  Future<bool> areEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<bool> ensurePermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return true;

    final enabled = await android.areNotificationsEnabled() ?? true;
    if (enabled) return true;

    final granted = await android.requestNotificationsPermission() ?? false;
    return granted;
  }

  Future<void> requestPermissionIfNeeded() async {
    await ensurePermission();
  }

  // ========= Tap handling =========

  void _onTapForeground(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // payload can be "taskId" (old) OR JSON {"taskId":"..","subTaskId":".."}
    try {
      if (payload.trim().startsWith('{')) {
        final data = jsonDecode(payload);
        final taskId = data['taskId'] as String?;
        final subTaskId = data['subTaskId'] as String?;

        if (taskId == null || taskId.isEmpty) return;

        Get.toNamed(
          '/focus',
          arguments: {
            'taskId': taskId,
            'subTaskId': subTaskId,
          },
        );
      } else {
        // backward compatible
        Get.toNamed('/focus', arguments: {'taskId': payload});
      }
    } catch (e) {
      debugPrint('❌ Invalid notification payload: $e payload=$payload');
    }
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Android background tap entry-point.
    // We keep it empty on purpose to avoid navigation issues in background isolate.
  }

  // ========= IDs =========

  int _hash(String input) => input.hashCode & 0x7fffffff;

  int _idOneShot(String taskId, String key) => _hash('$taskId|$key');
  int _idHourly(String taskId, String key) => _hash('$taskId|hourly|$key');
  int _idDaily(String taskId, String key) => _hash('$taskId|daily|$key');

  Future<void> cancelForTask(String taskId) async {
    const keys = [
      'dueSoon',
      'dueNow',
      'dueToday',
      'startSoon',
      'startToday',
      'todayNudge',
      'todayNudgeDaily',
    ];

    for (final k in keys) {
      await _plugin.cancel(_idOneShot(taskId, k));
      await _plugin.cancel(_idHourly(taskId, k));
      await _plugin.cancel(_idDaily(taskId, k));
    }
  }

  // ========= Schedulers =========

  Future<void> scheduleOneShot(
    String taskId,
    String key,
    DateTime when,
    String body, {
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      _idOneShot(taskId, key),
      'Task Reminder',
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks',
          'Tasks',
          channelDescription: 'Task reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// NOTE: flutter_local_notifications periodicShow is fixed interval (hourly/daily/weekly).
  /// We keep intervalHours param for your API shape, but it's still hourly repeating.
  Future<void> scheduleHourly(
    String taskId,
    String key,
    int intervalHours,
    String body, {
    String? payload,
  }) async {
    await _plugin.periodicallyShow(
      _idHourly(taskId, key),
      'Task Reminder',
      body,
      RepeatInterval.hourly,
      const NotificationDetails(
        android: AndroidNotificationDetails('tasks', 'Tasks'),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleDaily(
    String taskId,
    String key,
    String body, {
    int hour = 9,
    int minute = 0,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _idDaily(taskId, key),
      'Task Reminder',
      body,
      next,
      const NotificationDetails(
        android: AndroidNotificationDetails('tasks', 'Tasks'),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ========= Focus ongoing =========

  Future<void> showFocusOngoing({
    required int id,
    required String title,
    required int minutesLeft,
    String? payload, // optional: allow tapping focus ongoing too
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
      payload: payload,
    );
  }

  Future<void> cancelId(int id) async => _plugin.cancel(id);
}
