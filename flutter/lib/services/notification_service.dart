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

  static const int maxTodayRepeats = 12; // every 2 hours from 9am-9pm

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
          final rawTaskId = (data['taskId'] ?? '').toString();
          final taskId = rawTaskId.replaceAll(RegExp(r'[\[\]#]'), '');
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

  tz.TZDateTime _toFutureTz(DateTime when) {
    final nowTz = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime.from(when, tz.local);

    // If scheduled time is not strictly in the future, push it
    if (!t.isAfter(nowTz)) {
      t = nowTz.add(const Duration(minutes: 1));
    }
    return t;
  }

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
  int _idDaily(String taskId, String key) =>
      _stableHash32('$taskId|daily|$key');

  // -----------------------------
  // Cancel all schedules for a task
  // -----------------------------

  Future<void> cancelAllNotifications() async {
  await _plugin.cancelAll();
  debugPrint("💣 cancelAllNotifications done");
  }

  Future<void> cancelForTask(String taskId) async {
    final clean = taskId.replaceAll(RegExp(r'[\[\]#]'), '');

    const oneShotKeys = [kDueToday, kDueTime];
    const dailyKeys = [kDailyUntilDue];

    for (final k in oneShotKeys) {
      await _plugin.cancel(_idOneShot(clean, k));
    }
    for (final k in dailyKeys) {
      await _plugin.cancel(_idDaily(clean, k));
    }
    for (int i = 0; i < maxTodayRepeats; i++) {
      await _plugin.cancel(_idOneShot(clean, '$kTodayRepeatPrefix$i'));
    }

    debugPrint("🧹 cancelForTask done: task=$clean");
  }

  // -----------------------------
  // Core scheduling wrappers
  //   - inexactAllowWhileIdle avoids exact-alarm permission issues
  // -----------------------------

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        taskChannelId,
        taskChannelName,
        channelDescription: 'Task reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
  }

  Future<void> scheduleOneShot({
    required String taskId,
    required String key,
    required DateTime when,
    required String title,
    required String body,
    required String payload,
  }) async {
    final cleanTaskId = taskId.replaceAll(RegExp(r'[\[\]#]'), '');
    final id = _idOneShot(cleanTaskId, key); // ✅ stable + matches cancelForTask

    final tzWhen = _toFutureTz(when);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        _notificationDetails(), // make sure this exists
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('✅ one-shot: id=$id task=$cleanTaskId key=$key at=$tzWhen');
    } catch (e) {
      debugPrint(
          '❌ scheduleOneShot failed: id=$id task=$cleanTaskId key=$key err=$e');
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
      final cleanTaskId = taskId.replaceAll(RegExp(r'[\[\]#]'), '');
      final now = tz.TZDateTime.now(tz.local);
      var next =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (next.isBefore(now)) next = next.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        _idDaily(cleanTaskId, key),
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
    final target = DateTime(today.year, today.month, today.day, 9, 0);

    // If already past 09:00 today -> schedule in 1 minute
    final safe = target.isAfter(DateTime.now())
        ? target
        : DateTime.now().add(const Duration(minutes: 1));

    await scheduleOneShot(
      taskId: taskId,
      key: 'dueToday',
      when: safe,
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
    required DateTime endAt, // ✅ hard stop = dueTime
    required String title,
    required String body,
    required String payload,
    int startHour = 9,
  }) async {
    final now = DateTime.now();

    // ✅ Start window: today at startHour:00
    final windowStart = DateTime(now.year, now.month, now.day, startHour, 0);

    // ✅ Hard end: exact endAt (dueTime / 23:59 / etc.)
    final hardEnd = endAt;

    // If end already passed, skip
    if (!hardEnd.isAfter(now)) {
      debugPrint(
          "⏭️ scheduleEveryNHoursToday skip: end already passed (task=$taskId)");
      return;
    }

    // Start time = now + 1 min, align to next 5-min mark
    DateTime t = now.add(const Duration(minutes: 1));
    final bump = (5 - (t.minute % 5)) % 5;
    t = t.add(Duration(minutes: bump));

    // If still before start window -> jump to windowStart
    if (t.isBefore(windowStart)) t = windowStart;

    // If start is already >= hard end -> nothing to do
    if (!t.isBefore(hardEnd)) {
      debugPrint(
          "⏭️ scheduleEveryNHoursToday skip: start >= end (task=$taskId)");
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

    debugPrint(
        "✅ scheduleEveryNHoursToday done: task=$taskId count=$i endAt=$hardEnd");
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
