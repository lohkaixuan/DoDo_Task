// lib/controller/taskController.dart
import 'dart:async';
import 'package:get/get.dart';
import '../models/task.dart';
import '../api/dioclient.dart';
import '../services/notification_service.dart'; // 🔔

class TaskController extends GetxController {
  late final DioClient _dio;

  @override
  void onInit() {
    _dio = Get.find<DioClient>();
    super.onInit();
  }

  // ---------- State ----------
  final tasks = <Task>[].obs;

  // Focus timer state
  final timerActive = false.obs;
  final activeTimerTaskId = RxnString();
  final secondsLeft = 0.obs;         // countdown
  final sessionMinutes = 25.obs;     // default minutes
  Timer? _ticker;

  // ---------- Selectors ----------
  List<Task> get all => tasks;
  List<Task> get active => tasks.where((t) => !t.completed).toList();
  List<Task> get done   => tasks.where((t) =>  t.completed).toList();

  Task? get activeTask => activeTimerTaskId.value == null
      ? null
      : tasks.firstWhereOrNull((t) => t.id == activeTimerTaskId.value);

  // ---------- Demo seed ----------
  Future<void> seedIfEmpty() async {
    if (tasks.isNotEmpty) return;
    final now = DateTime.now();
    tasks.addAll([
      Task(id: 's1', title: 'Read 5 pages', mode: TaskMode.study, important: true,
           dueAt: now.add(const Duration(hours: 6)), priority: 2, estimateMinutes: 15),
      Task(id: 'w1', title: '10-min stretch', mode: TaskMode.wellness,
           dueAt: now.add(const Duration(hours: 2)), priority: 3, estimateMinutes: 10),
      Task(id: 'f1', title: 'Call mom', mode: TaskMode.family, priority: 3, estimateMinutes: 5),
      Task(id: 'p1', title: 'Tidy desk', mode: TaskMode.personal, priority: 4, estimateMinutes: 8),
    ]);
    tasks.refresh();
  }

  // ---------- CRUD (local first) ----------
  void remove(Task t) {
    tasks.removeWhere((x) => x.id == t.id);
    tasks.refresh();
    _syncDelete(t.id);
  }

  Task createLocal({
    required String id,
    required String title,
    String? desc,
    DateTime? dueAt,
    bool important = false,
    int estimateMinutes = 0,
    int priority = 3,
    TaskMode mode = TaskMode.personal,
  }) {
    final t = Task(
      id: id, title: title, desc: desc, dueAt: dueAt,
      important: important, estimateMinutes: estimateMinutes,
      priority: priority, mode: mode,
    );
    tasks.add(t);
    tasks.refresh();
    _syncCreate(t);
    return t;
  }

  void updateLocal({
    required String id,
    String? title, String? desc, DateTime? dueAt, bool? important,
    int? estimateMinutes, int? priority, TaskMode? mode,
    bool? completed, DateTime? completedAt,
  }) {
    final i = tasks.indexWhere((x) => x.id == id);
    if (i == -1) return;
    final cur = tasks[i];
    tasks[i] = cur.copyWith(
      title: title ?? cur.title,
      desc: desc ?? cur.desc,
      dueAt: dueAt ?? cur.dueAt,
      important: important ?? cur.important,
      estimateMinutes: estimateMinutes ?? cur.estimateMinutes,
      priority: priority ?? cur.priority,
      mode: mode ?? cur.mode,
      completed: completed ?? cur.completed,
      completedAt: completedAt ?? cur.completedAt,
    );
    tasks.refresh();
    _syncUpdate(tasks[i]);
  }

  void completeLocal(Task t) {
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i == -1) return;
    tasks[i] = tasks[i].copyWith(
      completed: true,
      completedAt: DateTime.now().toUtc(),
    );
    tasks.refresh();
    // If you want to ping the API too:
    // ignore: unawaited_futures
    _syncComplete(t.id);
  }

  void toggle(Task t) {
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i == -1) return;
    final nowDone = !tasks[i].completed;
    tasks[i] = tasks[i].copyWith(
      completed: nowDone,
      completedAt: nowDone ? DateTime.now().toUtc() : null,
    );
    tasks.refresh();
    if (nowDone) _syncComplete(t.id);
  }

  // ---------- Focus timer + notifications ----------
  int _notifIdFor(String taskId) => taskId.hashCode & 0x7fffffff; // stable int id

  void startFocus(Task t, {int? minutes}) {
    if (timerActive.value && activeTimerTaskId.value != t.id) {
      stopFocus();
    }
    activeTimerTaskId.value = t.id;
    final totalMin = minutes ?? sessionMinutes.value;
    secondsLeft.value = totalMin * 60;
    _startTicker();

    // 🔔 ongoing + ticker + end alert
    final nid = _notifIdFor(t.id);
    NotificationService.instance.showOngoing(
      id: nid,
      title: 'Focusing: ${t.title}',
      body: '$totalMin min • ${secondsLeft.value ~/ 60}m left',
      taskIdPayload: t.id,
    );
    NotificationService.instance.startOngoingTicker(
      id: nid,
      taskIdPayload: t.id,
      title: 'Focusing: ${t.title}',
      interval: const Duration(minutes: 1),
      remainingText: () => '$totalMin min • ${secondsLeft.value ~/ 60}m left',
    );
    NotificationService.instance.scheduleEnd(
      id: nid + 1,
      when: DateTime.now().add(Duration(seconds: secondsLeft.value)),
      title: 'Session done',
      body: 'Finished: ${t.title}',
      taskIdPayload: t.id,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    timerActive.value = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (tm) {
      final next = secondsLeft.value - 1;
      if (next <= 0) {
        tm.cancel();
        secondsLeft.value = 0;
        timerActive.value = false;
        final t = activeTask;
        final id = activeTimerTaskId.value;
        activeTimerTaskId.value = null;

        if (t != null) completeLocal(t);

        if (id != null) {
          final nid = _notifIdFor(id);
          NotificationService.instance.clearOngoing(nid);
          // keep the scheduled "end" alert to fire now
        }
      } else {
        secondsLeft.value = next;
      }
    });
  }

  void pauseFocus() {
    _ticker?.cancel();
    timerActive.value = false;

    final t = activeTask;
    if (t != null) {
      final nid = _notifIdFor(t.id);
      NotificationService.instance.updateOngoing(
        id: nid, title: 'Paused: ${t.title}',
        body: '${secondsLeft.value ~/ 60}m left', taskIdPayload: t.id,
      );
      NotificationService.instance.cancel(nid + 1); // cancel end while paused
    }
  }

  void resumeFocus() {
    final t = activeTask;
    if (t == null || secondsLeft.value <= 0 || timerActive.value) return;
    _startTicker();

    final nid = _notifIdFor(t.id);
    NotificationService.instance.updateOngoing(
      id: nid, title: 'Focusing: ${t.title}',
      body: '${secondsLeft.value ~/ 60}m left', taskIdPayload: t.id,
    );
    NotificationService.instance.scheduleEnd(
      id: nid + 1,
      when: DateTime.now().add(Duration(seconds: secondsLeft.value)),
      title: 'Session done',
      body: 'Finished: ${t.title}',
      taskIdPayload: t.id,
    );
  }

  void stopFocus() {
    _ticker?.cancel();
    timerActive.value = false;
    final id = activeTimerTaskId.value;
    activeTimerTaskId.value = null;
    if (id != null) {
      final nid = _notifIdFor(id);
      NotificationService.instance.clearOngoing(nid);
      NotificationService.instance.cancel(nid + 1);
    }
  }

  String get mmss {
    final m = (secondsLeft.value ~/ 60).toString().padLeft(2, '0');
    final s = (secondsLeft.value % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void onClose() {
    _ticker?.cancel();
    super.onClose();
  }

  // ---------- (Optional) server sync stubs ----------
  Future<void> _syncCreate(Task t) async { try { await _dio.dio.post('/tasks', data: t.toJson()); } catch (_) {} }
  Future<void> _syncUpdate(Task t) async { try { await _dio.dio.put('/tasks/${t.id}', data: t.toJson()); } catch (_) {} }
  Future<void> _syncDelete(String id) async { try { await _dio.dio.delete('/tasks/$id'); } catch (_) {} }
  Future<void> _syncComplete(String id) async { try { await _dio.dio.patch('/tasks/$id/complete'); } catch (_) {} }
}
