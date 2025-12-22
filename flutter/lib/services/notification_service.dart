// lib/services/notification_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // -----------------------------
  // Channel (Android)
  // -----------------------------
  static const String taskChannelId = 'tasks_channel';
  static const String taskChannelName = 'Tasks';

  static const String focusChannelId = 'focus_timer';
  static const String focusChannelName = 'Focus timer';

  // -----------------------------
  // Init
  // -----------------------------
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

          // ✅ deep link to Focus Timer
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

    // Create Android channels
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          taskChannelId,
          taskChannelName,
          description: 'Task reminders',
          importance: Importance.max,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          focusChannelId,
          focusChannelName,
          description: 'Shows current focus session',
          importance: Importance.low,
        ),
      );
    }

    debugPrint("✅ NotificationService.init done. tz=${tz.local.name}");
  }

  // -----------------------------
  // Permission helpers
  // -----------------------------
  Future<void> openAppNotificationSettings() async {
    await openAppSettings();
  }

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

    final ok = await android.requestNotificationsPermission() ?? false;
    debugPrint("🔔 requestNotificationsPermission => $ok");
    return ok;
  }

  // -----------------------------
  // ID helpers (stable per task+key)
  // -----------------------------
  int _hash(String input) => input.hashCode & 0x7fffffff;
  int _idOneShot(String taskId, String key) => _hash('$taskId|$key');
  int _idDaily(String taskId, String key) => _hash('$taskId|daily|$key');

  // -----------------------------
  // Cancel all possible schedules for a task
  // -----------------------------
  Future<void> cancelForTask(String taskId) async {
    // one-shot keys (must match all we ever schedule)
    const oneShotKeys = [
      'dueToday',
      'dueTime',
      'dueSoon',
      'startSoon',
      'startToday',
      'todayRepeat_0', // today repeats series
    ];

    // daily keys
    const dailyKeys = [
      'dailyUntilDue',
    ];

    // cancel one-shots
    for (final k in oneShotKeys) {
      await _plugin.cancel(_idOneShot(taskId, k));
    }

    // cancel daily
    for (final k in dailyKeys) {
      await _plugin.cancel(_idDaily(taskId, k));
    }

    // ✅ cancel today repeat series (we allow up to 48)
    for (int i = 0; i < 48; i++) {
      await _plugin.cancel(_idOneShot(taskId, 'todayRepeat_$i'));
    }

    debugPrint("🧹 cancelForTask done: task=$taskId");
  }

  // -----------------------------
  // Core scheduling wrappers
  //   - default inexactAllowWhileIdle to avoid exact-alarm crash
  //   - logs + try/catch
  // -----------------------------
  Future<void> scheduleOneShot({
    required String taskId,
    required String key,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final tzWhen = tz.TZDateTime.from(when, tz.local);

      await _plugin.zonedSchedule(
        _idOneShot(taskId, key),
        title,
        body,
        tzWhen,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            taskChannelId,
            taskChannelName,
            channelDescription: 'Task reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint(
          "✅ scheduled one-shot: task=$taskId key=$key at=$when (tz=${tzWhen.toString()})");
    } catch (e) {
      debugPrint("❌ scheduleOneShot failed: task=$taskId key=$key err=$e");
    }
  }

  /// A daily repeating reminder at time (HH:mm).
  /// Note: Android repeats until you cancel manually.
  Future<void> scheduleDailyAtTime({
    required String taskId,
    required String key,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (next.isBefore(now)) next = next.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        _idDaily(taskId, key),
        title,
        body,
        next,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            taskChannelId,
            taskChannelName,
            channelDescription: 'Task reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint("✅ scheduled daily: task=$taskId key=$key time=$hour:$minute");
    } catch (e) {
      debugPrint("❌ scheduleDailyAtTime failed: task=$taskId key=$key err=$e");
    }
  }

  // -----------------------------
  // New mechanism helpers
  // -----------------------------

  /// DueToday: "today 09:00" BUT if user creates it after 09:00,
  /// we "catch up" by scheduling 1 minute later (only if it's due today).
  Future<void> scheduleDueToday0900OrCatchUp({
    required String taskId,
    required DateTime today,
    required String title,
    required String body,
    required String payload,
  }) async {
    final target0900 = DateTime(today.year, today.month, today.day, 9, 0);

    // If already past 09:00 today, schedule 1 minute later (so user can see it)
    final when = (DateTime.now().isAfter(target0900))
        ? DateTime.now().add(const Duration(minutes: 1))
        : target0900;

    await scheduleOneShot(
      taskId: taskId,
      key: 'dueToday',
      when: when,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Schedule repeats today only: every N hours between [startHour..endHour],
  /// stops at endAt (or window end), max 48.
  Future<void> scheduleEveryNHoursToday({
    required String taskId,
    required int everyHours,
    required DateTime endAt,
    required String title,
    required String body,
    required String payload,
    int startHour = 9,
    int endHour = 21,
  }) async {
    final now = DateTime.now();

    // clamp window
    final windowStart = DateTime(now.year, now.month, now.day, startHour, 0);
    final windowEnd = DateTime(now.year, now.month, now.day, endHour, 0);

    // start time = next 5-min aligned moment
    DateTime t = now.add(const Duration(minutes: 1));
    final bump = (5 - (t.minute % 5)) % 5;
    t = t.add(Duration(minutes: bump));

    if (t.isBefore(windowStart)) t = windowStart;

    final hardEnd = endAt.isBefore(windowEnd) ? endAt : windowEnd;
    if (!t.isBefore(hardEnd)) {
      debugPrint("⏭️ scheduleEveryNHoursToday skip: start >= end (task=$taskId)");
      return;
    }

    int i = 0;
    final step = Duration(hours: everyHours <= 0 ? 2 : everyHours);

    while (t.isBefore(hardEnd) && i < 48) {
      await scheduleOneShot(
        taskId: taskId,
        key: 'todayRepeat_$i',
        when: t,
        title: title,
        body: body,
        payload: payload,
      );
      t = t.add(step);
      i++;
    }

    debugPrint("✅ scheduleEveryNHoursToday done: task=$taskId count=$i");
  }

  /// Ranged tasks: daily reminder until due date.
  /// Implementation: a repeating daily notification at 09:00.
  /// It will stop when you cancel (you already cancel on update/complete),
  /// and after due date you can re-fetch/reschedule to clean it.
  Future<void> scheduleDailyUntilDue({
    required String taskId,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    await scheduleDailyAtTime(
      taskId: taskId,
      key: 'dailyUntilDue',
      hour: hour,
      minute: minute,
      title: title,
      body: body,
      payload: payload,
    );
  }

  // -----------------------------
  // Debug
  // -----------------------------
  Future<void> debugPending() async {
    final list = await _plugin.pendingNotificationRequests();
    debugPrint("📌 pending count=${list.length}");
    for (final p in list) {
      debugPrint("📌 id=${p.id} title=${p.title} body=${p.body} payload=${p.payload}");
    }
  }

  Future<void> cancelId(int id) async => _plugin.cancel(id);

  // -----------------------------
  // Test immediate show (works even if scheduling fails)
  // -----------------------------
  Future<void> testNow() async {
    await _plugin.show(
      999999,
      'TEST 🦈',
      'If you see this, notifications work!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          taskChannelId,
          taskChannelName,
          channelDescription: 'Task reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  // -----------------------------
  // Focus ongoing
  // -----------------------------
  Future<void> showFocusOngoing({
    required int id,
    required String title,
    required int minutesLeft,
  }) async {
    const android = AndroidNotificationDetails(
      focusChannelId,
      focusChannelName,
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

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Android background tap entrypoint
  }
}
