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
  // Channels (Android)
  // -----------------------------
  static const String taskChannelId = 'tasks_channel';
  static const String taskChannelName = 'Tasks';

  static const String focusChannelId = 'focus_timer';
  static const String focusChannelName = 'Focus timer';

  // -----------------------------
  // Keys (keep consistent everywhere)
  // -----------------------------
  static const String kDueToday = 'dueToday';
  static const String kDueTime = 'dueTime';
  static const String kDailyUntilDue = 'dailyUntilDue';
  static const String kTodayRepeatPrefix = 'todayRepeat_';

  static const int maxTodayRepeats = 48;

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
  // Stable ID helpers (IMPORTANT)
  // hashCode is NOT stable across app restarts.
  // Use FNV-1a 32-bit
  // -----------------------------
  int _stableHash32(String s) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811C9DC5;
    for (final c in s.codeUnits) {
      hash ^= c;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  int _idOneShot(String taskId, String key) => _stableHash32('$taskId|$key');
  int _idDaily(String taskId, String key) => _stableHash32('$taskId|daily|$key');

  // -----------------------------
  // Cancel all schedules for a task
  // -----------------------------
  Future<void> cancelForTask(String taskId) async {
    // one-shot keys scheduled by TaskController
    const oneShotKeys = [
      kDueToday,
      kDueTime,
    ];

    // repeating daily keys
    const dailyKeys = [
      kDailyUntilDue,
    ];

    for (final k in oneShotKeys) {
      await _plugin.cancel(_idOneShot(taskId, k));
    }

    for (final k in dailyKeys) {
      await _plugin.cancel(_idDaily(taskId, k));
    }

    // today repeats
    for (int i = 0; i < maxTodayRepeats; i++) {
      await _plugin.cancel(_idOneShot(taskId, '$kTodayRepeatPrefix$i'));
    }

    debugPrint("🧹 cancelForTask done: task=$taskId");
  }

  // -----------------------------
  // Core scheduling wrappers
  //   - inexactAllowWhileIdle avoids exact-alarm permission issues
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
          "✅ scheduled one-shot: task=$taskId key=$key at=$when (tz=$tzWhen)");
    } catch (e) {
      debugPrint("❌ scheduleOneShot failed: task=$taskId key=$key err=$e");
    }
  }

  /// Daily repeating at HH:mm (Android repeats until cancel).
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
  // Task scheduling helpers
  // -----------------------------

  /// DueToday: schedule at 09:00 today; if it's already past 09:00,
  /// schedule 1 minute later (only for "due today" behavior).
  Future<void> scheduleDueToday0900OrCatchUp({
    required String taskId,
    required DateTime today,
    required String title,
    required String body,
    required String payload,
  }) async {
    final target0900 = DateTime(today.year, today.month, today.day, 9, 0);
    final now = DateTime.now();

    final when = now.isAfter(target0900)
        ? now.add(const Duration(minutes: 1))
        : target0900;

    await scheduleOneShot(
      taskId: taskId,
      key: kDueToday,
      when: when,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Repeats today only: every N hours between [startHour..endHour],
  /// stops at endAt (or window end). Max [maxTodayRepeats].
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

    final windowStart = DateTime(now.year, now.month, now.day, startHour, 0);
    final windowEnd = DateTime(now.year, now.month, now.day, endHour, 0);

    // Start time = next 5-min aligned moment (>= now+1min)
    DateTime t = now.add(const Duration(minutes: 1));
    final bump = (5 - (t.minute % 5)) % 5;
    t = t.add(Duration(minutes: bump));

    if (t.isBefore(windowStart)) t = windowStart;

    final hardEnd = endAt.isBefore(windowEnd) ? endAt : windowEnd;
    if (!t.isBefore(hardEnd)) {
      debugPrint("⏭️ scheduleEveryNHoursToday skip: start >= end (task=$taskId)");
      return;
    }

    final step = Duration(hours: everyHours <= 0 ? 2 : everyHours);

    int i = 0;
    while (t.isBefore(hardEnd) && i < maxTodayRepeats) {
      await scheduleOneShot(
        taskId: taskId,
        key: '$kTodayRepeatPrefix$i',
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
  /// Implementation: a repeating daily notification at HH:mm.
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
      key: kDailyUntilDue,
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
      debugPrint(
          "📌 id=${p.id} title=${p.title} body=${p.body} payload=${p.payload}");
    }
  }

  Future<void> cancelId(int id) async => _plugin.cancel(id);

  // -----------------------------
  // Test immediate show
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
    // If you want: store payload to prefs and handle on next app open.
    // debugPrint('BG tap payload=${response.payload}');
  }
}
