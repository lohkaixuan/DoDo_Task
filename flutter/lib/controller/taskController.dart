// ==================================================
// Program Name   : taskController.dart
// Purpose        : Manage task lifecycle including creation, update, deletion, status transitions, focus tracking, and productivity events.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 22 August 2025
// Last Modified  : 14 December 2025
// ==================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;

import 'package:v3/api/dioclient.dart';
import 'package:v3/models/task.dart';
import 'package:v3/services/notification_service.dart';
import 'package:v3/storage/authStorage.dart';

import 'petController.dart';
import 'walletController.dart';
import 'settingController.dart';
import 'package:v3/services/tts_service.dart';
import 'package:v3/services/wellbeing_service.dart';

class TaskController extends GetxController {
  final tasks = <Task>[].obs;

  final NotificationService notifier;
  final PetController pet;

  final DioClient _dioClient = Get.find<DioClient>();
  late final WalletController walletC;
  late final SettingController settingC;
  //final _eventSvc = WellbeingEventService();
  Worker? _settingsWorker;

  bool _fetching = false;

  TaskController(this.notifier, this.pet);

  @override
  void onInit() {
    super.onInit();

    walletC = Get.find<WalletController>();
    settingC = Get.find<SettingController>();

    // settings change => debounce reschedule
    final settingsSig = 0.obs;
    ever(settingC.mediumRepeatEnabled, (_) => settingsSig.value++);
    ever(settingC.mediumRepeatHours, (_) => settingsSig.value++);
    ever(settingC.lowRepeatEnabled, (_) => settingsSig.value++);
    ever(settingC.lowRepeatHours, (_) => settingsSig.value++);

    _settingsWorker = debounce<int>(
      settingsSig,
      (_) => _rescheduleAllIfLoggedIn(),
      time: const Duration(milliseconds: 400),
    );
  }

  @override
  void onClose() {
    _settingsWorker?.dispose();
    super.onClose();
  }

  // =========================================================
  // Auth Guard
  // =========================================================
  Future<bool> _isLoggedIn() async {
    final token = await AuthStorage.readToken();
    final email = await AuthStorage.readUserEmail();
    return token != null &&
        token.trim().isNotEmpty &&
        email != null &&
        email.trim().isNotEmpty;
  }

  Future<void> _rescheduleAllIfLoggedIn() async {
    if (!await _isLoggedIn()) return;

    final snapshot = List<Task>.from(tasks);
    Future.microtask(() async {
      await notifier.ensurePermission();
      for (final t in snapshot) {
        await _scheduleAllNotifications(t);
        await Future.delayed(const Duration(milliseconds: 10));
      }
    });
  }

  // =========================================================
  // Fetch
  // =========================================================
  Future<void> fetchTasks() async {
    if (_fetching) return;

    if (!await _isLoggedIn()) {
      debugPrint("⛔ fetchTasks blocked: not logged in");
      return;
    }

    _fetching = true;
    try {
      final email = await AuthStorage.readUserEmail();
      if (email == null || email.isEmpty) return;

      final res = await _dioClient.dio.get('/tasks/$email');
      if (res.data is! List) return;

      final list = (res.data as List).map((e) {
        final m = Map<String, dynamic>.from(e);
        if (m['flutter_id'] != null) m['id'] = m['flutter_id'];
        return Task.fromJson(m);
      }).toList();

      tasks.assignAll(list);

      Future.microtask(() async {
        await notifier.ensurePermission();
        for (final t in list) {
          await _scheduleAllNotifications(t);
          await Future.delayed(const Duration(milliseconds: 10));
        }
      });
    } catch (e) {
      debugPrint('⚠️ fetchTasks failed: $e');
    } finally {
      _fetching = false;
    }
  }

  // =========================================================
  // Add
  // =========================================================
  Future<void> addTask(Task t) async {
    if (!await _isLoggedIn()) return;

    tasks.add(t);
    update();

    await _scheduleAllNotifications(t);

    try {
      final body = t.toJson();
      body.remove('id');
      body['flutter_id'] = _cleanId(t.id);

      final email = await AuthStorage.readUserEmail();
      body['user_email'] = email ?? 'guest@dodo.com';

      body['status'] = t.status.name;
      body['type'] = t.type.name;
      body['priority'] = t.priority.name;

      await _dioClient.dio.post('/tasks', data: body);
    } catch (e) {
      debugPrint('⚠️ addTask sync failed: $e');
    }
  }

  // =========================================================
  // Update
  // =========================================================
  Future<dio.Response?> updateTask(Task t) async {
    if (!await _isLoggedIn()) return null;

    final idx = tasks.indexWhere((x) => x.id == t.id);
    if (idx < 0) return null;

    final before = tasks[idx];
    tasks[idx] = t;
    update();

    _petReactOnStatus(before, t);
    await _scheduleAllNotifications(t);

    final body = t.toJson();
    body.remove('id');
    body['flutter_id'] = _cleanId(t.id);

    final email = await AuthStorage.readUserEmail();
    body['user_email'] = email;

    body['status'] = t.status.name;
    body['type'] = t.type.name;
    body['priority'] = t.priority.name;

    try {
      return await _dioClient.dio.put('/tasks/${_cleanId(t.id)}', data: body);
    } catch (e) {
      debugPrint('⚠️ updateTask failed: $e');
      return null;
    }
  }

  // =========================================================
  // Complete / Undo
  // =========================================================
  Future<void> completeTask(String id) async {
    final idx = tasks.indexWhere((x) => x.id == id);
    if (idx < 0) return;

    final before = tasks[idx];
    if (before.status == TaskStatus.completed) return;
    debugPrint("✅ completed -> now sending task_complete event");

    final after = before.copyWith(
      status: TaskStatus.completed,
      updatedAt: DateTime.now(),
    );

    final res = await updateTask(after);
    await _sendEvent(
      "task_complete",
      context: {
        "task_id": _cleanId(id),
        "title": after.title,
        "priority": after.priority.name,
      },
    );
    final data = res?.data;
    final coins = (data is Map) ? data['coins'] : null;

    if (coins != null) {
      walletC.coins.value = (coins as num).toInt();
    } else {
      walletC.fetchBalance();
    }

    try {
      await TtsService.instance.speak("Nice one! One task down ✨");
    } catch (_) {}
  }

  Future<void> undoComplete(String id) async {
    final idx = tasks.indexWhere((x) => x.id == id);
    if (idx < 0) return;

    final before = tasks[idx];
    if (before.status != TaskStatus.completed) return;

    final after = before.copyWith(status: TaskStatus.notStarted);

    final res = await updateTask(after);
    final data = res?.data;
    final coins = (data is Map) ? data['coins'] : null;

    if (coins != null) {
      walletC.coins.value = (coins as num).toInt();
    } else {
      walletC.fetchBalance();
    }
  }

  // =========================================================
  // Delete
  // =========================================================
  Future<void> removeById(String id) async {
    await notifier.cancelForTask(id);

    tasks.removeWhere((x) => x.id == id);
    update();

    if (!await _isLoggedIn()) return;

    try {
      await _dioClient.dio.delete('/tasks/${_cleanId(id)}');
    } catch (e) {
      debugPrint('⚠️ delete failed: $e');
    }
  }

  Future<void> clearAll() async {
    for (final t in tasks) {
      await notifier.cancelForTask(t.id);
    }
    tasks.clear();
    update();
  }

  // =========================================================
  // Subtasks & Focus
  // =========================================================
  void addSubTask(String taskId, SubTask s) {
    final i = tasks.indexWhere((x) => x.id == taskId);
    if (i < 0) return;

    final t = tasks[i];
    updateTask(t.copyWith(subtasks: [...t.subtasks, s]));
  }

  void setSubTaskStatus(String taskId, String subId, SubTaskStatus status) {
    final i = tasks.indexWhere((x) => x.id == taskId);
    if (i < 0) return;

    final t = tasks[i];
    final subs = t.subtasks
        .map((s) => s.id == subId ? s.copyWith(status: status) : s)
        .toList();

    updateTask(t.copyWith(
      subtasks: subs,
      status: t.progress >= 1.0
          ? TaskStatus.completed
          : t.computeStatus(DateTime.now()),
    ));
  }

  void markInProgress(String id) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;

    final t = tasks[i];
    if (t.status != TaskStatus.inProgress) {
      updateTask(t.copyWith(status: TaskStatus.inProgress));
    
    _sendEvent(
      "focus_start",
      context: {
        "task_id": _cleanId(id),
      },
    );

      try {
        TtsService.instance.speak("Focus mode on. I’m with you ");
      } catch (_) {}
    }
  }

  // =========================================================
  // Recommendation (Dashboard)
  // =========================================================
  double _recommendScore(Task t, DateTime now) {
    if (t.status == TaskStatus.completed || t.status == TaskStatus.archived) {
      return -9999;
    }

    final pri = switch (t.priority) {
      PriorityLevel.urgent => 4.0,
      PriorityLevel.high => 3.0,
      PriorityLevel.medium => 2.0,
      PriorityLevel.low => 1.0,
    };

    final imp = t.important ? 1.2 : 0.0;

    double due = 0;
    if (t.type == TaskType.singleDay && t.dueDateTime != null) {
      final mins = t.dueDateTime!.difference(now).inMinutes;
      due = (mins <= 0) ? 3.0 : (1440 - mins).clamp(0, 1440) / 1440 * 2.0;
    } else if (t.type == TaskType.ranged && t.dueDate != null) {
      final end = DateTime(
          t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59, 59);
      final mins = end.difference(now).inMinutes;
      due = (mins <= 0) ? 2.5 : (4320 - mins).clamp(0, 4320) / 4320 * 1.7;
    }

    final int est = t.estimatedMinutes ??
        t.subtasks.fold<int>(0, (a, s) => a + (s.estimatedMinutes ?? 0));

    final double quick = (est == 0)
        ? 0.3
        : (est <= 30)
            ? 0.6
            : (est <= 60)
                ? 0.3
                : 0.0;

    return pri + imp + due + quick;
  }

  List<Task> recommended({int max = 5}) {
    final now = DateTime.now();
    final candidates = tasks
        .where((t) =>
            t.status != TaskStatus.completed && t.status != TaskStatus.archived)
        .toList();

    candidates.sort(
        (a, b) => _recommendScore(b, now).compareTo(_recommendScore(a, now)));
    return candidates.take(max).toList();
  }
  
  // =========================================================
  // Send Event
  // =========================================================

  Future<void> _sendEvent(String type, {Map<String, dynamic>? context}) async {
    try {
      await _dioClient.dio.post(
        "/wellbeing/events",
        data: {
          "event_id": DateTime.now().millisecondsSinceEpoch.toString(),
          "type": type,
          "context": context ?? {},
        },
      );
    } catch (e) {
      debugPrint("❌ sendEvent failed: $e");
    }
  }

  // =========================================================
  // Helpers
  // =========================================================
  String _cleanId(String id) => id.replaceAll(RegExp(r'[\[\]#]'), '');

  bool _repeatAllowed(Task t) {
    return switch (t.priority) {
      PriorityLevel.urgent => true,
      PriorityLevel.high => true,
      PriorityLevel.medium => settingC.mediumRepeatEnabled.value,
      PriorityLevel.low => settingC.lowRepeatEnabled.value,
    };
  }

  int _repeatHours(Task t) {
    return switch (t.priority) {
      PriorityLevel.urgent => 1,
      PriorityLevel.high => 2,
      PriorityLevel.medium => settingC.mediumRepeatHours.value,
      PriorityLevel.low => settingC.lowRepeatHours.value,
    };
  }

  String _payloadForTask(Task t, {String? subTaskId}) {
    return jsonEncode({'taskId': _cleanId(t.id), 'subTaskId': subTaskId});
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // =========================================================
  // Notifications Scheduling (keep your logic)
  // =========================================================
  Future<void> _scheduleAllNotifications(Task t) async {
    // ✅ ALWAYS cancel old schedules first (even when logged out)
    await notifier.cancelForTask(_cleanId(t.id));

    // ✅ guard: only schedule when logged in
    if (!await _isLoggedIn()) {
      debugPrint("⛔ schedule blocked: not logged in (task=${t.id})");
      return;
    }

    // skip if completed/archived
    if (t.status == TaskStatus.completed || t.status == TaskStatus.archived) {
      return;
    }

    final now = DateTime.now();

    final bool dueToday = (t.type == TaskType.singleDay &&
            t.dueDateTime != null &&
            _isSameDay(t.dueDateTime!, now)) ||
        (t.type == TaskType.ranged &&
            t.dueDate != null &&
            _isSameDay(t.dueDate!, now));

    final bool allowNormalNoti = t.focusPrefs.notificationsEnabled;

    // if not due today AND user disabled notifications -> no schedule
    if (!dueToday && !allowNormalNoti) return;

    final payload = _payloadForTask(t);

    // -------------------------
    // A) singleDay + dueDateTime
    // -------------------------
    if (t.type == TaskType.singleDay && t.dueDateTime != null) {
      final due = t.dueDateTime!;
      final isDueToday = _isSameDay(due, now);

      // "Start" = 9:00 on due day (simple and consistent)
      final startAt = DateTime(due.year, due.month, due.day, 9, 0);

      // 1) Remind BEFORE start (e.g., 1 day before 9:00)
      if (allowNormalNoti && t.notify.remindBeforeStart) {
        final when = startAt.subtract(t.notify.remindBeforeStartOffset);
        if (when.isAfter(now)) {
          await notifier.scheduleOneShot(
            taskId: _cleanId(t.id),
            key: 'beforeStart',
            when: when,
            title: 'Task Reminder',
            body: "Upcoming: ‘${t.title}’. Tap to plan and focus.",
            payload: payload,
          );
        }
      }

      // 2) Remind ON start (9:00)
      if (allowNormalNoti && t.notify.remindOnStart) {
        if (isDueToday) {
          await notifier.scheduleDueToday0900OrCatchUp(
            taskId: _cleanId(t.id),
            today: now,
            title: 'Task Reminder',
            body: "Start today: ‘${t.title}’. Tap to begin focus!",
            payload: payload,
          );
        } else {
          await notifier.scheduleOneShot(
            taskId: _cleanId(t.id),
            key: 'onStart',
            when: startAt,
            title: 'Task Reminder',
            body: "Start today: ‘${t.title}’. Tap to begin focus!",
            payload: payload,
          );
        }
      }

      // 3) Remind BEFORE due time
      if (allowNormalNoti && t.notify.remindBeforeDue) {
        final when = due.subtract(t.notify.remindBeforeDueOffset);
        final safe = when.isAfter(now) ? when : now.add(const Duration(minutes: 1));
        if (safe.isBefore(due)) {
          await notifier.scheduleOneShot(
            taskId: _cleanId(t.id),
            key: 'beforeDue',
            when: safe,
            title: 'Task Reminder',
            body: "Due soon: ‘${t.title}’. Small push now ✨",
            payload: payload,
          );
        }
      }

      // 4) Remind ON due time
      if (t.notify.remindOnDue) {
        final dueSafe = due.isAfter(now) ? due : now.add(const Duration(minutes: 1));
        await notifier.scheduleOneShot(
          taskId: _cleanId(t.id),
          key: 'onDue',
          when: dueSafe,
          title: 'Task Reminder',
          body: "Due now: ‘${t.title}’. Final push! Tap to focus.",
          payload: payload,
        );
      }

      // 5) Repeats (due-today only)
      final canRepeat = isDueToday &&
          allowNormalNoti &&
          _repeatAllowed(t) &&
          now.isBefore(due) &&
          t.notify.repeatWhenToday != RepeatGranularity.none;

      if (canRepeat) {
        // base hours from priority + user repeat interval
        int everyHours = _repeatHours(t);
        final ri = t.notify.repeatInterval <= 0 ? 1 : t.notify.repeatInterval;
        everyHours = (everyHours * ri).clamp(1, 24);

        // notifier needs a "startHour" (0-23)
        final safeStart = now.isAfter(startAt)
            ? now.add(const Duration(minutes: 1))
            : startAt;

        if (safeStart.isBefore(due)) {
          await notifier.scheduleEveryNHoursToday(
            taskId: _cleanId(t.id),
            everyHours: everyHours,
            endAt: due,
            title: 'Task Reminder',
            body: "Due today: ‘${t.title}’. Tap to focus!",
            payload: payload,
            startHour: safeStart.hour,
          );
        }
      }

      return;
    }

    // -------------------------
    // B) ranged + dueDate (all-day)
    // -------------------------
    if (t.type == TaskType.ranged && t.dueDate != null) {
      final d = t.dueDate!;
      final due0900 = DateTime(d.year, d.month, d.day, 9, 0);
      final dueEnd = DateTime(d.year, d.month, d.day, 23, 59);

      if (!dueEnd.isAfter(now)) return;

      final isDueToday = _isSameDay(d, now);

      // 1) Due day morning reminder
      if (allowNormalNoti && t.notify.remindOnStart) {
        if (isDueToday) {
          await notifier.scheduleDueToday0900OrCatchUp(
            taskId: _cleanId(t.id),
            today: now,
            title: 'Task Reminder',
            body: "Due today: ‘${t.title}’. Tap to start focus!",
            payload: payload,
          );
        } else {
          await notifier.scheduleOneShot(
            taskId: _cleanId(t.id),
            key: 'dueDay0900',
            when: due0900,
            title: 'Task Reminder',
            body: "Due today: ‘${t.title}’. Tap to start focus!",
            payload: payload,
          );
        }
      }

      // 2) Before due end (offset)
      if (allowNormalNoti && t.notify.remindBeforeDue) {
        final when = dueEnd.subtract(t.notify.remindBeforeDueOffset);
        final safe = when.isAfter(now) ? when : now.add(const Duration(minutes: 1));
        if (safe.isBefore(dueEnd)) {
          await notifier.scheduleOneShot(
            taskId: _cleanId(t.id),
            key: 'beforeDue',
            when: safe,
            title: 'Task Reminder',
            body: "Due soon: ‘${t.title}’. Tap to focus!",
            payload: payload,
          );
        }
      }

      // 3) On due end
      if (t.notify.remindOnDue) {
        final safe = dueEnd.isAfter(now) ? dueEnd : now.add(const Duration(minutes: 1));
        await notifier.scheduleOneShot(
          taskId: _cleanId(t.id),
          key: 'onDue',
          when: safe,
          title: 'Task Reminder',
          body: "Due today: ‘${t.title}’. Final push!",
          payload: payload,
        );
      }

      // 4) Repeat reminders on due day (optional)
      final canRepeat = isDueToday &&
          allowNormalNoti &&
          _repeatAllowed(t) &&
          t.notify.repeatWhenToday != RepeatGranularity.none;

      if (canRepeat) {
        int everyHours = _repeatHours(t);
        final ri = t.notify.repeatInterval <= 0 ? 1 : t.notify.repeatInterval;
        everyHours = (everyHours * ri).clamp(1, 24);

        final safeStart = now.isAfter(due0900)
            ? now.add(const Duration(minutes: 1))
            : due0900;

        if (safeStart.isBefore(dueEnd)) {
          await notifier.scheduleEveryNHoursToday(
            taskId: _cleanId(t.id),
            everyHours: everyHours,
            endAt: dueEnd,
            title: 'Task Reminder',
            body: "Due today: ‘${t.title}’. Tap to focus!",
            payload: payload,
            startHour: safeStart.hour,
          );
        }
      }

      // 5) Daily reminder until due date (if enabled)
      if (allowNormalNoti) {
        final hour = t.notify.dailyHour ?? 9;
        final minute = t.notify.dailyMinute ?? 0;
        await notifier.scheduleDailyUntilDue(
          taskId: _cleanId(t.id),
          hour: hour,
          minute: minute,
          title: 'Task Reminder',
          body: "Reminder: work on ‘${t.title}’ today. Tap to focus.",
          payload: payload,
        );
      }

      return;
    }

    // C) fallback -> do nothing
  }

  // =========================================================
  // Pet reaction (核心：完成/逾期都能触发 Dashboard 更新)
  // =========================================================
  void _petReactOnStatus(Task before, Task after) {
    final now = DateTime.now();

    final beforeComputed = before.computeStatus(now);
    final afterComputed = after.computeStatus(now);

    // late transition
    if (beforeComputed != TaskStatus.late && afterComputed == TaskStatus.late) {
      pet.onTaskLate();
      try {
        TtsService.instance
            .speak("It’s okay… we can still fix this together. Lets go ");
      } catch (_) {}
    }

    // started transition
    if (beforeComputed == TaskStatus.notStarted &&
        afterComputed == TaskStatus.inProgress) {
      pet.onFocusStart();
    }

    // completed transition
    final beforeDone = before.status == TaskStatus.completed;
    final afterDone = after.status == TaskStatus.completed;
    if (!beforeDone && afterDone) {
      pet.onTaskCompleted(); // ✅ 无参，永远安全
      try {
        TtsService.instance.speak("Mission complete! Proud of you ✨");
      } catch (_) {}
    }
  }
}
