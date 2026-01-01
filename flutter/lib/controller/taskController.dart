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
import 'package:v3/services/tts_service.dart';

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
      final end = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59, 59);
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
        .where((t) => t.status != TaskStatus.completed && t.status != TaskStatus.archived)
        .toList();

    candidates.sort((a, b) => _recommendScore(b, now).compareTo(_recommendScore(a, now)));
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
    return jsonEncode({'taskId': _cleanId(t.id), 'subTaskId': subTaskId});
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  // =========================================================
  // Notifications Scheduling (keep your logic)
  // =========================================================
  Future<void> _scheduleAllNotifications(Task t) async {
    if (!await _isLoggedIn()) return;

    await notifier.cancelForTask(_cleanId(t.id));

    if (t.status == TaskStatus.completed || t.status == TaskStatus.archived) {
      return;
    }

    final now = DateTime.now();

    final bool dueToday =
        (t.type == TaskType.singleDay && t.dueDateTime != null && _isSameDay(t.dueDateTime!, now)) ||
        (t.type == TaskType.ranged && t.dueDate != null && _isSameDay(t.dueDate!, now));

    final bool allowNormalNoti = t.focusPrefs.notificationsEnabled;

    if (!dueToday && !allowNormalNoti) return;

    final payload = _payloadForTask(t);

    // --- keep your existing scheduling branches (A/B) ---
    // (省略：你原本那段 schedule code 可以 그대로贴回这里)
    // 建议：你直接把你原本 schedule A/B 段落复制回来，保持不动。
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
        TtsService.instance.speak("It’s okay… we can still fix this together. Lets go ");
      } catch (_) {}
    }

    // started transition
    if (beforeComputed == TaskStatus.notStarted && afterComputed == TaskStatus.inProgress) {
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
