// lib/services/notification_service.dart
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
    //const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final taskId = response.payload; // payload = task id
        if (taskId == null || taskId.isEmpty) return;

        // 你要怎么跳转随你，这里给一个最简单的 debug：
        debugPrint("🔔 Notification clicked payload=$taskId");
        // 如果你要 GetX 跳转：
        Get.toNamed('/focus', arguments: {'taskId': taskId});
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> requestPermissionIfNeeded() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  int _hash(String input) => input.hashCode & 0x7fffffff;

  int _idOneShot(String taskId, String key) => _hash('$taskId|$key');
  int _idHourly(String taskId, String key) => _hash('$taskId|hourly|$key');
  int _idDaily(String taskId, String key) => _hash('$taskId|daily|$key');

  Future<void> cancelForTask(String taskId) async {
    // ✅ 只取消这个 task 的所有可能通知
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

  // ---------- Hourly repeating ----------
  // (If you need "every 2 hours", schedule your own rolling one-shots.)
  Future<void> scheduleHourly(
    String taskId,
    String key,
    int intervalHours,
    String body, {
    String? payload,
  }) async {
    // ⚠️ flutter_local_notifications 的 periodic 是固定“每小时/每天/每周”
    // 我们这里用“每小时”作为基础，如果你想 every N hours，需要更复杂的链式 one-shot。
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
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
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

  @pragma('vm:entry-point')
  void notificationTapBackground(NotificationResponse response) {
    // 背景点通知也会进来（Android）
  }
}
