// lib/controller/taskController.dart
import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart' as dio;

import '../api/dioclient.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import 'petController.dart';
import '../storage/authStorage.dart';
import '../controller/walletController.dart';

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
  // Fetch Tasks
  // =========================================================
  Future<void> fetchTasks() async {
    try {
      final email = await AuthStorage.readUserEmail();
      if (email == null || email.isEmpty) return;

      final res = await _dioClient.dio.get('/tasks/$email');

      if (res.data is! List) return;

      final list = (res.data as List).map((e) {
        e['id'] = e['flutter_id'];
        return Task.fromJson(e);
      }).toList();

      tasks.assignAll(list);

      for (final t in list) {
        _scheduleAllNotifications(t);
      }
    } catch (e) {
      print("⚠️ fetchTasks failed: $e");
    }
  }

    // =========================
// Add Task
// =========================
Future<void> addTask(Task t) async {
  // 1) 本地先加（UI 立即看到）
  tasks.add(t);
  update();
  _scheduleAllNotifications(t);

  // 2) 云端同步
  try {
    final body = t.toJson();

    // 不发 id（Mongo internal），只发 flutter_id
    body.remove('id');
    final cleanId = t.id.replaceAll(RegExp(r'[\[\]#]'), '');
    body['flutter_id'] = cleanId;

    final email = await AuthStorage.readUserEmail();
    body['user_email'] = email ?? "guest@dodo.com";

    body['status'] = t.status.name;
    body['type'] = t.type.name;
    body['priority'] = t.priority.name;

    await _dioClient.dio.post('/tasks', data: body);
  } catch (e) {
    print("⚠️ addTask sync failed: $e");
  }
}

// =========================
// Recommendation
// =========================
double _recommendScore(Task t, DateTime now) {
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
    final end = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59, 59);
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

  final done = t.status == TaskStatus.completed ? -999.0 : 0.0;
  return pri + imp + due + quick + done;
}

List<Task> recommended({int max = 5}) {
  final now = DateTime.now();
  final candidates = tasks.where((t) => t.status != TaskStatus.completed).toList();
  candidates.sort((a, b) => _recommendScore(b, now).compareTo(_recommendScore(a, now)));
  return candidates.take(max).toList();
}

  // =========================================================
  // Update Task (IMPORTANT: return Response)
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
    body['flutter_id'] = t.id;

    final email = await AuthStorage.readUserEmail();
    body['user_email'] = email;

    body['status'] = t.status.name;
    body['type'] = t.type.name;
    body['priority'] = t.priority.name;

    try {
      return await _dioClient.dio.put(
        '/tasks/${t.id}',
        data: body,
      );
    } catch (e) {
      print("⚠️ updateTask failed: $e");
      return null;
    }
  }

  // =========================================================
  // Complete Task (方案 A：后端算 coins)
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
      print("🪙 Coins updated from backend: $coins");
    } else {
      walletC.fetchBalance();
    }
  }

  // =========================================================
  // Undo Complete (后端自动扣 coins)
  // =========================================================
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
  void removeById(String id) async {
    notifier.cancelForTask(id);
    tasks.removeWhere((x) => x.id == id);
    update();

    try {
      await _dioClient.dio.delete('/tasks/$id');
    } catch (e) {
      print("⚠️ delete failed: $e");
    }
  }

  void remove(Task t) => removeById(t.id);

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

  void startFocusOnSubTask(String taskId, String subId, int minutes) {
    pet.onFocusStart(minutes);
    final i = tasks.indexWhere((x) => x.id == taskId);
    if (i >= 0) {
      updateTask(tasks[i].copyWith(status: TaskStatus.inProgress));
    }
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
  // Helpers
  // =========================================================
  void _scheduleAllNotifications(Task t) {
    notifier.cancelForTask(t.id);
  }

  void _petReactOnStatus(Task before, Task after) {
    final now = DateTime.now();
    if (before.computeStatus(now) != TaskStatus.late &&
        after.computeStatus(now) == TaskStatus.late) {
      pet.onTaskLate();
    }
    if (before.computeStatus(now) == TaskStatus.notStarted &&
        after.computeStatus(now) == TaskStatus.inProgress) {
      pet.onTaskStarted();
    }
  }

// =========================
// Demo Data
// =========================
void seedDemo({int count = 16}) {
  clearAll();
  final now = DateTime.now();
  final cats = ['Study', 'Wellness', 'Family', 'Personal'];
  int uid = 0;

  PriorityLevel pickPri(int i) => switch (i % 4) {
        0 => PriorityLevel.urgent,
        1 => PriorityLevel.high,
        2 => PriorityLevel.medium,
        _ => PriorityLevel.low,
      };

  for (int i = 0; i < count; i++) {
    final isSingle = i % 2 == 0;
    final cat = cats[i % cats.length];
    final pri = pickPri(i);
    final important = (i % 3 != 0);
    final est = [20, 30, 45, 60, 90, 120][i % 6];

    final t = Task(
      id: 'seed_${uid++}',
      title: isSingle ? 'Finish $cat task $i' : 'Work on $cat project $i',
      category: cat,
      type: isSingle ? TaskType.singleDay : TaskType.ranged,
      dueDateTime: isSingle ? now.add(Duration(hours: (i % 8) * 3 + 2)) : null,
      startDate: isSingle ? null : now.subtract(Duration(days: i % 2)),
      dueDate: isSingle ? null : now.add(Duration(days: 1 + (i % 5))),
      priority: pri,
      important: important,
      estimatedMinutes: est,
    );

    addTask(t);
  }
}
}
