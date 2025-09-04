// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Callbacks supplied by your app
typedef OnSelectTaskFromNotification = Future<void> Function(String taskId);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // We keep a ticker per task id to periodically update "m left".
  final Map<int, Timer> _ongoingTickers = {};

  OnSelectTaskFromNotification? _onSelectTask;

  Future<void> init({OnSelectTaskFromNotification? onSelectTask}) async {
    if (_initialized) return;
    _onSelectTask = onSelectTask;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      // Taps on notifications (foreground/background/terminated)
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload ?? '';
        if (payload.startsWith('focus:')) {
          final taskId = payload.substring('focus:'.length);
          if (_onSelectTask != null) {
            await _onSelectTask!(taskId);
          }
        }
      },
    );

    // Notification runtime permission (Android 13+); safe to no-op on iOS/older
    if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: true);
    }

    _initialized = true;
  }

  // ===== Ongoing =====

  Future<void> showOngoing({
    required int id,
    required String title,
    required String body,
    required String taskIdPayload,
  }) async {
    await init();

    if (!Platform.isAndroid) {
      // iOS doesn't support true ongoing; still show a normal one.
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(presentSound: false),
        ),
        payload: 'focus:$taskIdPayload',
      );
      return;
    }

    const android = AndroidNotificationDetails(
      'focus_timer_running',
      'Focus Timer (Running)',
      channelDescription: 'Shows remaining time while a focus timer runs',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      playSound: false,
      showWhen: true,
      category: AndroidNotificationCategory.progress,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: android),
      payload: 'focus:$taskIdPayload',
    );
  }

  Future<void> updateOngoing({
    required int id,
    required String title,
    required String body,
    required String taskIdPayload,
  }) async {
    // Re-issue same id = updates it
    await showOngoing(
      id: id,
      title: title,
      body: body,
      taskIdPayload: taskIdPayload,
    );
  }

  Future<void> clearOngoing(int id) async {
    // Also cancel the ticker if any
    _ongoingTickers.remove(id)?.cancel();
    await _plugin.cancel(id);
  }

  /// Start a periodic updater (every [interval]) that calls [remainingText]
  /// and updates the ongoing notification body.
  void startOngoingTicker({
    required int id,
    required String taskIdPayload,
    required String title,
    required String Function() remainingText, // e.g. "25 min total • 23m left"
    Duration interval = const Duration(minutes: 3),
  }) {
    _ongoingTickers.remove(id)?.cancel(); // in case already exists
    _ongoingTickers[id] = Timer.periodic(interval, (_) async {
      await updateOngoing(
        id: id,
        title: title,
        body: remainingText(),
        taskIdPayload: taskIdPayload,
      );
    });
  }

  // ===== End alert =====

  Future<void> scheduleEnd({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? taskIdPayload,
  }) async {
    await init();
    final tzWhen = tz.TZDateTime.from(when, tz.local);

    const android = AndroidNotificationDetails(
      'focus_timer_end',
      'Focus Timer (End)',
      channelDescription: 'Alerts when focus session ends',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const ios = DarwinNotificationDetails(presentSound: true);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      const NotificationDetails(android: android, iOS: ios),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskIdPayload != null ? 'focus:$taskIdPayload' : null,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() async {
    for (final t in _ongoingTickers.values) {
      t.cancel();
    }
    _ongoingTickers.clear();
    await _plugin.cancelAll();
  }
}
