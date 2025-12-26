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

class TaskController extends GetxController {
  final tasks = <Task>[].obs;

  final NotificationService notifier;
  final PetController pet;

  final DioClient _dioClient = Get.find<DioClient>();
  late final WalletController walletC;
  late final SettingController settingC;
  Worker? _settingsWorker;

  TaskController(this.notifier, this.pet);

  @override
  void onInit() {
    super.onInit();

    walletC = Get.find<WalletController>();
    settingC = Get.find<SettingController>();

    // ✅ settings debounce reschedule
    final settingsSig = 0.obs;
    ever(settingC.mediumRepeatEnabled, (_) => settingsSig.value++);
    ever(settingC.mediumRepeatHours, (_) => settingsSig.value++);
    ever(settingC.lowRepeatEnabled, (_) => settingsSig.value++);
    ever(settingC.lowRepeatHours, (_) => settingsSig.value++);

    _settingsWorker = debounce<int>(
      settingsSig,
      (_) => _rescheduleAll(),
      time: const Duration(milliseconds: 400),
    );

    // ✅ delay fetch until first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchTasks();
    });
  }

  @override
  void onClose() {
    _settingsWorker?.dispose();
    super.onClose();
  }

  Future<void> _rescheduleAll() async {
    final snapshot = List<Task>.from(tasks);
    Future.microtask(() async {
      for (final t in snapshot) {
        await _scheduleAllNotifications(t);
        await Future.delayed(const Duration(milliseconds: 10));
      }
    });
  }

  // =========================================================
  // Fetch
  // =========================================================
  bool _fetching = false;
  Future<void> fetchTasks() async {
    if (_fetching) return;
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
        // ✅ permission 只做一次（下面 Step 2 会讲）
        await notifier.ensurePermission();
        for (final t in list) {
          await _scheduleAllNotifications(t);
          await Future.delayed(const Duration(milliseconds: 10));
        }
      });
    } catch (e) {
      print('⚠️ fetchTasks failed: $e');
    } finally {
      _fetching = false;
    }
  }

  // =========================================================
  // Add
  // =========================================================
  Future<void> addTask(Task t) async {
    // local first
    tasks.add(t);
    update();

    // schedule local right away
    await _scheduleAllNotifications(t);
    await notifier.debugPending();

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
      print('⚠️ addTask sync failed: $e');
    }
  }

  // =========================================================
  // Update (return Response for coins)
  // =========================================================
  Future<dio.Response?> updateTask(Task t) async {
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
      print('⚠️ updateTask failed: $e');
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

    try {
      await _dioClient.dio.delete('/tasks/${_cleanId(id)}');
    } catch (e) {
      print('⚠️ delete failed: $e');
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
    }
  }

  // =========================================================
  // Recommendation (for Dashboard)
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
  // Notifications Scheduling (core)
  // =========================================================
  Future<void> _scheduleAllNotifications(Task t) async {
    // 1) cancel old schedules first
    await notifier.cancelForTask(_cleanId(t.id));

    // 2) skip if completed/archived
    if (t.status == TaskStatus.completed || t.status == TaskStatus.archived) {
      return;
    }

    final now = DateTime.now();

    // 判定是否 due today（singleDay: dueDateTime / ranged: dueDate）
    final bool dueToday = (t.type == TaskType.singleDay &&
            t.dueDateTime != null &&
            _isSameDay(t.dueDateTime!, now)) ||
        (t.type == TaskType.ranged &&
            t.dueDate != null &&
            _isSameDay(t.dueDate!, now));

    // ✅ 今天 due 一定要提醒一次
    final bool allowNormalNoti = t.focusPrefs.notificationsEnabled;

    // 如果不是 due today 且用户关了通知，就直接不排任何
    if (!dueToday && !allowNormalNoti) return;

    final payload = _payloadForTask(t);

    /*bool _notiChecked = false;
    Future<void> _ensureNotiOnce() async {
      if (_notiChecked) return;
      _notiChecked = true;
      await notifier.ensurePermission();
    }*/

    // -------------------------
    // A) singleDay + dueDateTime
    // -------------------------
    if (t.type == TaskType.singleDay && t.dueDateTime != null) {
      final due = t.dueDateTime!;
      final dueDay0900 = DateTime(due.year, due.month, due.day, 9, 0);
      final isDueToday = _isSameDay(due, now);

      // 1) DueToday once @ 9:00 (or catch up if already past 9)
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

      // 2) DueTime once (ALWAYS must exist)
      // If already past due time, schedule 1 min later so you still see it.
      final dueSafe =
          due.isAfter(now) ? due : now.add(const Duration(minutes: 1));

      await notifier.scheduleOneShot(
        taskId: _cleanId(t.id),
        key: 'dueTime',
        when: dueSafe,
        title: 'Task Reminder',
        body: "Due now: ‘${t.title}’. Final push! Tap to focus.",
        payload: payload,
      );

      // 3) Repeats before dueTime (due-today only)
      final allowNormalNoti = t.focusPrefs.notificationsEnabled;

      // ✅ 你要的是：还没到 dueTime 才重复
      final canRepeat = isDueToday &&
          allowNormalNoti &&
          _repeatAllowed(t) &&
          (t.startDate == null) &&
          now.isBefore(due); // <-- super important

      if (canRepeat) {
        final hours = _repeatHours(t);

        // start from max(9:00, now+1min) to avoid scheduling in the past
        final startAt = DateTime(due.year, due.month, due.day, 9, 0);
        final safeStart = now.isAfter(startAt)
            ? now.add(const Duration(minutes: 1))
            : startAt;

        // only repeat if the window makes sense
        if (safeStart.isBefore(due)) {
          await notifier.scheduleEveryNHoursToday(
            taskId: _cleanId(t.id),
            everyHours: hours,
            endAt: due, // stop at dueTime ✅
            title: 'Task Reminder',
            body: "Due today: ‘${t.title}’. Tap to focus!",
            payload: payload,
            startHour: safeStart.hour, // optional: align start
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
      final dueToday0900 =
          DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
      final dueTime =
          DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59);

      // If already past due date end, don't schedule
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

        // Due day repeats ONLY (A plan)
        final canRepeat = allowNormalNoti && _repeatAllowed(t);
        final hours = _repeatHours(t);

        if (canRepeat) {
          await notifier.scheduleEveryNHoursToday(
            taskId: _cleanId(t.id),
            everyHours: hours,
            endAt: dueTime, // ✅ ranged due day ends 23:59
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

      // Daily reminder once/day until due date (only if enabled)
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

    // -------------------------
    // C) fallback (no due info) -> do nothing
    // -------------------------
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
    }

    // started (notStarted -> inProgress)
    if (before.computeStatus(now) == TaskStatus.notStarted &&
        after.computeStatus(now) == TaskStatus.inProgress) {
      pet.onFocusStart();
    }
  }
}
