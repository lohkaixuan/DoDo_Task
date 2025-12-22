// lib/controller/taskController.dart
import 'dart:convert';

import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;

import '../api/dioclient.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../storage/authStorage.dart';
import 'petController.dart';
import 'walletController.dart';

class TaskController extends GetxController {
  final tasks = <Task>[].obs;

  final NotificationService notifier;
  final PetController pet;

  final DioClient _dioClient = Get.find<DioClient>();
  late final WalletController walletC;

  TaskController(this.notifier, this.pet);

  @override
  void onInit() {
    super.onInit();
    walletC = Get.find<WalletController>();
    fetchTasks();
  }

  // =========================================================
  // Fetch
  // =========================================================
  Future<void> fetchTasks() async {
    try {
      final email = await AuthStorage.readUserEmail();
      if (email == null || email.isEmpty) return;

      final res = await _dioClient.dio.get('/tasks/$email');
      if (res.data is! List) return;

      final list = (res.data as List).map((e) {
        final m = Map<String, dynamic>.from(e);
        // backend uses flutter_id, app uses id
        if (m['flutter_id'] != null) m['id'] = m['flutter_id'];
        return Task.fromJson(m);
      }).toList();

      tasks.assignAll(list);

      // schedule notifications for all tasks
      for (final t in list) {
        _scheduleAllNotifications(t);
      }
    } catch (e) {
      print('⚠️ fetchTasks failed: $e');
    }
  }

  // =========================================================
  // Add
  // =========================================================
  Future<void> addTask(Task t) async {
    // local first
    tasks.add(t);
    update();
    _scheduleAllNotifications(t);

    try {
      final body = t.toJson();
      body.remove('id');

      final cleanId = _cleanId(t.id);
      body['flutter_id'] = cleanId;

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
    _scheduleAllNotifications(t);

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
    notifier.cancelForTask(id);
    tasks.removeWhere((x) => x.id == id);
    update();

    try {
      await _dioClient.dio.delete('/tasks/${_cleanId(id)}');
    } catch (e) {
      print('⚠️ delete failed: $e');
    }
  }

  Future<void> remove(Task t) => removeById(t.id);

  void clearAll() {
    for (final t in tasks) {
      notifier.cancelForTask(t.id);
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
    // ignore completed
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

    // "quick win" boost
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
  // Helpers
  // =========================================================
  String _cleanId(String id) => id.replaceAll(RegExp(r'[\[\]#]'), '');

  String _payloadForTask(Task t, {String? subTaskId}) {
    return jsonEncode({
      'taskId': t.id,
      'subTaskId': subTaskId, // keep null if not used
    });
  }

  void _scheduleAllNotifications(Task t) {
  notifier.cancelForTask(t.id);

  // finished tasks should not keep nudging
  if (t.status == TaskStatus.completed || t.status == TaskStatus.archived) return;

  // if user disabled notifications at task level, skip
  if (!t.focusPrefs.notificationsEnabled) return;

  final now = DateTime.now();
  final payload = _payloadForTask(t); // json with taskId + subTaskId(null)

  // helper: compute "endAt" for today
  DateTime _todayEndAt() {
    if (t.type == TaskType.singleDay && t.dueDateTime != null) {
      return t.dueDateTime!;
    }
    if (t.type == TaskType.ranged && t.dueDate != null) {
      return DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59);
    }
    return DateTime(now.year, now.month, now.day, 23, 59);
  }

  // ✅ TODAY SMART NUDGES (works for both singleDay & ranged when due today)
  if (t.isDueToday(now) && t.notify.repeatWhenToday != RepeatGranularity.none) {
    if (t.notify.repeatWhenToday == RepeatGranularity.hour) {
      // smart: every N hours, only during 09:00–21:00, stops today
      notifier.scheduleSmartTodayNudges(
        taskId: t.id,
        body: "Due today: ‘${t.title}’. Tap to start focus!",
        intervalHours: t.notify.repeatInterval <= 0 ? 1 : t.notify.repeatInterval,
        endAt: _todayEndAt(),
        payload: payload,
        startHour: 9,
        endHour: 21,
      );
    } else if (t.notify.repeatWhenToday == RepeatGranularity.day) {
      // one daily nudge at preferred time
      notifier.scheduleDaily(
        t.id,
        'todayNudgeDaily',
        "Due today: ‘${t.title}’. Tap to start focus!",
        hour: t.notify.dailyHour ?? 9,
        minute: t.notify.dailyMinute ?? 0,
        payload: payload,
      );
    }
  }

    // ===== ranged: startDate + dueDate =====
    if (t.type == TaskType.ranged && t.startDate != null && t.dueDate != null) {
      // start soon
      if (t.notify.remindBeforeStart) {
        final dt = t.startDate!.subtract(t.notify.remindBeforeStartOffset);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(
            t.id,
            'startSoon',
            dt,
            "‘${t.title}’ starts soon. Plan your first session.",
            payload: payload,
          );
        }
      }

      // start today (08:00)
      if (t.notify.remindOnStart) {
        final dt = DateTime(
            t.startDate!.year, t.startDate!.month, t.startDate!.day, 8, 0);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(
            t.id,
            'startToday',
            dt,
            "‘${t.title}’ starts today. Kick off with 25 min!",
            payload: payload,
          );
        }
      }

      // due soon (23:59 - offset)
      if (t.notify.remindBeforeDue) {
        final end =
            DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59);
        final dt = end.subtract(t.notify.remindBeforeDueOffset);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(
            t.id,
            'dueSoon',
            dt,
            "‘${t.title}’ due soon. Wrap up remaining subtasks.",
            payload: payload,
          );
        }
      }

      // due today (23:59)
      if (t.notify.remindOnDue) {
        final dt =
            DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(
            t.id,
            'dueToday',
            dt,
            "‘${t.title}’ due today. Final push!",
            payload: payload,
          );
        }
      }
    }
  }

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
