// lib/services/notification_service.dart
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:get/get.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final data = jsonDecode(payload);
          final taskId = data['taskId'];
          final subTaskId = data['subTaskId'];

          // ✅ jump to Focus Timer
          Get.toNamed('/focus', arguments: {
            'taskId': taskId,
            'subTaskId': subTaskId,
          });
        } catch (e) {
          debugPrint('❌ Invalid payload: $e');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  // ---------- Permission helpers ----------
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

    return await android.requestNotificationsPermission() ?? false;
  }

  // ---------- IDs ----------
  int _hash(String input) => input.hashCode & 0x7fffffff;
  int _idOneShot(String taskId, String key) => _hash('$taskId|$key');
  int _idHourly(String taskId, String key) => _hash('$taskId|hourly|$key');
  int _idDaily(String taskId, String key) => _hash('$taskId|daily|$key');

  // ✅ cancel all possible scheduled notifications for a task
  Future<void> cancelForTask(String taskId) async {
    const keys = [
      'dueSoon',
      'dueNow',
      'dueToday',
      'startSoon',
      'startToday',
      'todayNudgeDaily',
    ];

    for (final k in keys) {
      await _plugin.cancel(_idOneShot(taskId, k));
      await _plugin.cancel(_idHourly(taskId, k));
      await _plugin.cancel(_idDaily(taskId, k));
    }

    // ✅ NEW: cancel smart "today nudges" series
    // we schedule with keys like todaySmart_0..todaySmart_40
    for (int i = 0; i < 48; i++) {
      await _plugin.cancel(_idOneShot(taskId, 'todaySmart_$i'));
    }
  }

  // ---------- One-shot ----------
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

  // ---------- Daily at a time ----------
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

  // ✅ NEW: Smart "Due Today" nudges
  // Schedules multiple one-shots today only (e.g. every N hours between 09:00-21:00).
  Future<void> scheduleSmartTodayNudges({
    required String taskId,
    required String body,
    required int intervalHours,
    required DateTime endAt, // usually due time or 23:59
    required String payload,
    int startHour = 9,
    int endHour = 21,
  }) async {
    final now = DateTime.now();

    // Align start time to next "nice" moment (next 5 min)
    DateTime start = now.add(const Duration(minutes: 1));
    final m = start.minute;
    final bump = (5 - (m % 5)) % 5;
    start = start.add(Duration(minutes: bump));

    // Clamp within allowed window today
    final windowStart = DateTime(now.year, now.month, now.day, startHour, 0);
    final windowEnd = DateTime(now.year, now.month, now.day, endHour, 0);

    DateTime t = start.isBefore(windowStart) ? windowStart : start;
    final hardEnd = endAt.isBefore(windowEnd) ? endAt : windowEnd;

    if (!t.isBefore(hardEnd)) return;

    int i = 0;
    while (t.isBefore(hardEnd) && i < 48) {
      await scheduleOneShot(
        taskId,
        'todaySmart_$i',
        t,
        body,
        payload: payload,
      );

      // next tick
      t = t.add(Duration(hours: intervalHours <= 0 ? 1 : intervalHours));
      i++;
    }
  }

  // ---------- Focus ongoing ----------
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

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Android background tap entrypoint
  }
}
