// lib/controller/taskController.dart
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
import 'package:v3/services/tts_service.dart'; // ✅ 你把 PetTalkService 放这里了

class TaskController extends GetxController {
  final tasks = <Task>[].obs;

  final NotificationService notifier;
  final PetController pet;

  final DioClient _dioClient = Get.find<DioClient>();
  late final WalletController walletC;
  late final SettingController settingC;
  Worker? _settingsWorker;

  bool _fetching = false;

  TaskController(this.notifier, this.pet);

  @override
  void onInit() {
    super.onInit();

    walletC = Get.find<WalletController>();
    settingC = Get.find<SettingController>();

    // ✅ settings change => debounce reschedule
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
  // ✅ Auth Guard helpers
  // =========================================================
  Future<bool> _isLoggedIn() async {
    final token = await AuthStorage.readToken();
    final email = await AuthStorage.readUserEmail();
    return token != null &&
        token.trim().isNotEmpty &&
        email != null &&
        email.trim().isNotEmpty;
  }

  // =========================================================
  // ✅ Reschedule all (only when logged in)
  // =========================================================
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

    // ✅ 改动 1：fetchTasks 先挡掉未登录
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

      // ✅ 改动 2：只在登录状态下才 schedule + permission
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
    // ✅ 改动 3：未登录直接不让 add（避免 guest task + 排程）
    if (!await _isLoggedIn()) return;

    // local first
    tasks.add(t);
    update();

    // schedule local right away
    await _scheduleAllNotifications(t);

    // sync backend
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
  // Update (return Response for coins)
  // =========================================================
  Future<dio.Response?> updateTask(Task t) async {
    // ✅ 改动 4：update 也挡掉未登录（否则 put 会 401/422）
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
  // Complete / Undo (backend calculates coins)
  // =========================================================
  Future<void> completeTask(String id) async {
    final idx = tasks.indexWhere((x) => x.id == id);
    if (idx < 0) return;

    final before = tasks[idx];
    if (before.status == TaskStatus.completed) return;

    final after = before.copyWith(
      status: TaskStatus.completed,
      updatedAt: DateTime.now(),
    );

    final res = await updateTask(after);
    final data = res?.data;
    final coins = (data is Map) ? data['coins'] : null;

    if (coins != null) {
      walletC.coins.value = (coins as num).toInt();
    } else {
      walletC.fetchBalance();
    }

    // ✅ 可选：完成任务时让宠物说一句（你刚刚选 3 很帅）
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

    // ✅ 如果未登录就不打后端
    if (!await _isLoggedIn()) return;

    try {
      await _dioClient.dio.delete('/tasks/${_cleanId(id)}');
    } catch (e) {
      debugPrint('⚠️ delete failed: $e');
    }
  }

  Future<void> remove(Task t) => removeById(t.id);

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

      // ✅ 可选：开始 focus 说一句
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
      if (mins <= 0) {
        due = 3.0;
      } else {
        due = (1440 - mins).clamp(0, 1440) / 1440 * 2.0;
      }
    } else if (t.type == TaskType.ranged && t.dueDate != null) {
      final end = DateTime(
        t.dueDate!.year,
        t.dueDate!.month,
        t.dueDate!.day,
        23,
        59,
        59,
      );
      final mins = end.difference(now).inMinutes;
      if (mins <= 0) {
        due = 2.5;
      } else {
        due = (4320 - mins).clamp(0, 4320) / 4320 * 1.7;
      }
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
      (a, b) => _recommendScore(b, now).compareTo(_recommendScore(a, now)),
    );

    return candidates.take(max).toList();
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
    return jsonEncode({
      'taskId': _cleanId(t.id),
      'subTaskId': subTaskId,
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // =========================================================
  // ✅ Notifications Scheduling (core)
  // =========================================================
  Future<void> _scheduleAllNotifications(Task t) async {
    // ✅ 改动 5：最早就挡掉未登录（避免 logout 后还 schedule）
    if (!await _isLoggedIn()) return;

    // 1) cancel old schedules first
    await notifier.cancelForTask(_cleanId(t.id));

    // 2) skip if completed/archived
    if (t.status == TaskStatus.completed || t.status == TaskStatus.archived) {
      return;
    }

    final now = DateTime.now();

    // due today?
    final bool dueToday = (t.type == TaskType.singleDay &&
            t.dueDateTime != null &&
            _isSameDay(t.dueDateTime!, now)) ||
        (t.type == TaskType.ranged &&
            t.dueDate != null &&
            _isSameDay(t.dueDate!, now));

    final bool allowNormalNoti = t.focusPrefs.notificationsEnabled;

    // not due today + notifications disabled => schedule nothing
    if (!dueToday && !allowNormalNoti) return;

    final payload = _payloadForTask(t);

    // -------------------------
    // A) singleDay + dueDateTime
    // -------------------------
    if (t.type == TaskType.singleDay && t.dueDateTime != null) {
      final due = t.dueDateTime!;
      final dueDay0900 = DateTime(due.year, due.month, due.day, 9, 0);
      final isDueToday = _isSameDay(due, now);

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
          key: 'dueToday',
          when: dueDay0900,
          title: 'Task Reminder',
          body: "Due today: ‘${t.title}’. Tap to start focus!",
          payload: payload,
        );
      }

      // DueTime once
      final dueSafe = due.isAfter(now) ? due : now.add(const Duration(minutes: 1));
      await notifier.scheduleOneShot(
        taskId: _cleanId(t.id),
        key: 'dueTime',
        when: dueSafe,
        title: 'Task Reminder',
        body: "Due now: ‘${t.title}’. Final push! Tap to focus.",
        payload: payload,
      );

      // repeats before dueTime (due-today only)
      final canRepeat = isDueToday &&
          allowNormalNoti &&
          _repeatAllowed(t) &&
          (t.startDate == null) &&
          now.isBefore(due);

      if (canRepeat) {
        final hours = _repeatHours(t);

        final startAt = DateTime(due.year, due.month, due.day, 9, 0);
        final safeStart = now.isAfter(startAt)
            ? now.add(const Duration(minutes: 1))
            : startAt;

        if (safeStart.isBefore(due)) {
          await notifier.scheduleEveryNHoursToday(
            taskId: _cleanId(t.id),
            everyHours: hours,
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
    // B) ranged + dueDate
    // -------------------------
    if (t.type == TaskType.ranged && t.dueDate != null) {
      final dueDate = t.dueDate!;
      final dueToday0900 = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
      final dueTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59);

      if (!dueTime.isAfter(now)) return;

      // DueToday once
      if (_isSameDay(dueDate, now)) {
        await notifier.scheduleDueToday0900OrCatchUp(
          taskId: _cleanId(t.id),
          today: now,
          title: 'Task Reminder',
          body: "Due today: ‘${t.title}’. Tap to start focus!",
          payload: payload,
        );

        final canRepeat = allowNormalNoti && _repeatAllowed(t);
        if (canRepeat) {
          final hours = _repeatHours(t);
          await notifier.scheduleEveryNHoursToday(
            taskId: _cleanId(t.id),
            everyHours: hours,
            endAt: dueTime,
            title: 'Task Reminder',
            body: "Due today: ‘${t.title}’. Tap to focus!",
            payload: payload,
            startHour: 9,
          );
        }
      } else {
        await notifier.scheduleOneShot(
          taskId: _cleanId(t.id),
          key: 'dueToday',
          when: dueToday0900,
          title: 'Task Reminder',
          body: "Due today: ‘${t.title}’. Tap to start focus!",
          payload: payload,
        );
      }

      // DueTime once
      await notifier.scheduleOneShot(
        taskId: _cleanId(t.id),
        key: 'dueTime',
        when: dueTime,
        title: 'Task Reminder',
        body: "Due now: ‘${t.title}’. It’s the deadline (23:59).",
        payload: payload,
      );

      // Daily reminder once/day until due
      if (allowNormalNoti) {
        await notifier.scheduleDailyUntilDue(
          taskId: _cleanId(t.id),
          hour: 9,
          minute: 0,
          title: 'Task Reminder',
          body: "Reminder: work on ‘${t.title}’ today. Tap to focus.",
          payload: payload,
        );
      }

      return;
    }
  }

  // =========================================================
  // Pet reaction
  // =========================================================
  void _petReactOnStatus(Task before, Task after) {
    final now = DateTime.now();

    // became late
    if (before.computeStatus(now) != TaskStatus.late &&
        after.computeStatus(now) == TaskStatus.late) {
      pet.onTaskLate();

      // ✅ 可选：late 时宠物安慰一句
      try {
        TtsService.instance.speak("It’s okay… we can still fix this together. Lets go ");
      } catch (_) {}
    }

    // started (notStarted -> inProgress)
    if (before.computeStatus(now) == TaskStatus.notStarted &&
        after.computeStatus(now) == TaskStatus.inProgress) {
      pet.onFocusStart();
    }
  }
}
