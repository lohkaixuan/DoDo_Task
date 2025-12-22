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
        await _scheduleAllNotifications(t);
        print(
            "🔍 task=${t.title} type=${t.type} dueDateTime=${t.dueDateTime} start=${t.startDate} dueDate=${t.dueDate}");
      }
      await notifier.debugPending();
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
    await _scheduleAllNotifications(t);

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

  // --- helper: payload (keep subTaskId for deep-link) ---
  String _payloadForTask(Task t, {String? subTaskId}) {
    return jsonEncode({
      'taskId': t.id,
      'subTaskId': subTaskId, // keep null if not used
    });
  }

// --- helper: date-only compare ---
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _scheduleAllNotifications(Task t) async {
    // 1) cancel old schedules first
    await notifier.cancelForTask(t.id);

    // 2) skip if completed/archived
    if (t.status == TaskStatus.completed || t.status == TaskStatus.archived)
      return;

    // 3) skip if task-level notifications disabled
    if (!t.focusPrefs.notificationsEnabled) return;

    // 4) ensure permission (do not block scheduling hard, but good practice)
    await notifier.ensurePermission();

    final now = DateTime.now();
    final payload = _payloadForTask(t);

    // -------------------------
    // A) singleDay + dueDateTime
    // -------------------------
    if (t.type == TaskType.singleDay && t.dueDateTime != null) {
      final due = t.dueDateTime!;
      final dueDay0900 = DateTime(due.year, due.month, due.day, 9, 0);  
  // ✅ DueToday @ 09:00 on the due day (catch up if today & already past 09:00)
  if (_isSameDay(due, now)) {
    await notifier.scheduleDueToday0900OrCatchUp(
      taskId: t.id,
      today: now,
      title: 'Task Reminder',
      body: "Due today: ‘${t.title}’. Tap to start focus!",
      payload: payload,
    );
  } else {
    await notifier.scheduleOneShot(
      taskId: t.id,
      key: 'dueToday',
      when: dueDay0900,
      title: 'Task Reminder',
      body: "Due today: ‘${t.title}’. Tap to start focus!",
      payload: payload,
    );
  }

  // ✅ DueTime (safe)
  // - If due already passed but still today -> fire in 1 minute
  // - If due is in the past and not today -> skip
  if (!_isSameDay(due, now) && !due.isAfter(now)) {
    // past day -> skip dueTime
  } else {
    final dueSafe = (_isSameDay(due, now) && !due.isAfter(now))
        ? now.add(const Duration(minutes: 1))
        : due;

    await notifier.scheduleOneShot(
      taskId: t.id,
      key: 'dueTime',
      when: dueSafe,
      title: 'Task Reminder',
      body: "Due now: ‘${t.title}’. Final push! Tap to focus.",
      payload: payload,
    );
  }

  // ✅ every 2 hours reminder (only if today + no start + due after 09:00)
  final noStart = (t.startDate == null);
  final startWindow = DateTime(due.year, due.month, due.day, 9, 0);
  if (noStart && _isSameDay(due, now) && due.isAfter(startWindow)) {
    await notifier.scheduleEveryNHoursToday(
      taskId: t.id,
      everyHours: 2,
      endAt: due,
      title: 'Task Reminder',
      body: "Due today: ‘${t.title}’. Tap to start focus!",
      payload: payload,
      startHour: 9,
      endHour: 21,
    );
  }

  return; // done singleDay
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

      // ✅ DueToday @ 09:00 on due date
      if (_isSameDay(dueDate, now)) {
        await notifier.scheduleDueToday0900OrCatchUp(
          taskId: t.id,
          today: now,
          title: 'Task Reminder',
          body: "Due today: ‘${t.title}’. Tap to start focus!",
          payload: payload,
        );

        // On the due day, you wanted it to behave like the “dueDateTime procedure”
        // -> we do every 2 hours today until 23:59
        await notifier.scheduleEveryNHoursToday(
          taskId: t.id,
          everyHours: 2,
          endAt: dueTime,
          title: 'Task Reminder',
          body: "Due today: ‘${t.title}’. Tap to focus!",
          payload: payload,
          startHour: 9,
          endHour: 21,
        );
      } else {
        await notifier.scheduleOneShot(
          taskId: t.id,
          key: 'dueToday',
          when: dueToday0900,
          title: 'Task Reminder',
          body: "Due today: ‘${t.title}’. Tap to start focus!",
          payload: payload,
        );
      }

      // ✅ DueTime @ dueDate 23:59
      await notifier.scheduleOneShot(
        taskId: t.id,
        key: 'dueTime',
        when: dueTime,
        title: 'Task Reminder',
        body: "Due now: ‘${t.title}’. It’s the deadline (23:59).",
        payload: payload,
      );

      // ✅ Daily reminder once/day until due date (09:00)
      // Note: With a repeating daily schedule, Android will keep it until you cancel.
      // In your flow, you already call cancelForTask() on update/complete/fetch, so it will
      // naturally stop once task becomes completed/archived or app re-schedules after due.
      await notifier.scheduleDailyUntilDue(
        taskId: t.id,
        hour: 9,
        minute: 0,
        title: 'Task Reminder',
        body: "Reminder: work on ‘${t.title}’ today. Tap to focus.",
        payload: payload,
      );

      return; // done
    }

    // -------------------------
    // C) fallback (no due info)
    // -------------------------
    // If task has no dueDateTime/dueDate, do nothing
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
