// lib/controller/taskController.dart
import 'package:get/get.dart';
import 'package:collection/collection.dart';

import '../models/task.dart';
import '../services/notification_service.dart';
import 'petController.dart';

class TaskController extends GetxController {
  final tasks = <Task>[].obs;
  final NotificationService notifier;
  final PetController pet;

  TaskController(this.notifier, this.pet);

  // ===== CRUD =====
  void addTask(Task t) {
    tasks.add(t);
    _scheduleAllNotifications(t);
    update();
  }

  void updateTask(Task t) {
    final idx = tasks.indexWhere((x) => x.id == t.id);
    if (idx >= 0) {
      final before = tasks[idx];
      final after = t.copyWith(updatedAt: DateTime.now());
      tasks[idx] = after;
      _scheduleAllNotifications(after);
      _petReactOnStatus(before, after);
      update();
    }
  }

  void removeById(String id) {
    notifier.cancelForTask(id);
    tasks.removeWhere((x) => x.id == id);
    update();
  }

  void remove(Task t) => removeById(t.id);

  void completeTask(String id) {
    final idx = tasks.indexWhere((x) => x.id == id);
    if (idx >= 0) {
      final before = tasks[idx];
      final now = DateTime.now();
      final after = before.copyWith(status: TaskStatus.completed, updatedAt: now);
      tasks[idx] = after;
      notifier.cancelForTask(id);

      // Determine early/on-time/late
      bool early = false, onTime = false, late = false;
      if (after.type == TaskType.singleDay && after.dueDateTime != null) {
        early = now.isBefore(after.dueDateTime!);
        onTime = !early && now.difference(after.dueDateTime!).inMinutes.abs() <= 5;
        late = now.isAfter(after.dueDateTime!);
      } else if (after.type == TaskType.ranged && after.dueDate != null) {
        final dueEnd = DateTime(after.dueDate!.year, after.dueDate!.month, after.dueDate!.day, 23, 59, 59);
        early = now.isBefore(dueEnd);
        onTime = !early && now.difference(dueEnd).inMinutes.abs() <= 5;
        late = now.isAfter(dueEnd);
      }

      pet.onTaskCompleted(early: early, onTime: onTime, late: late);
      update();
    }
  }

  // Remove everything (used by settings/demo)
  void clearAll() {
    for (final t in tasks) {
      notifier.cancelForTask(t.id);
    }
    tasks.clear();
    update();
  }

  // ===== Subtasks =====
  void addSubTask(String taskId, SubTask s) {
    final i = tasks.indexWhere((x) => x.id == taskId);
    if (i < 0) return;
    final list = [...tasks[i].subtasks, s];
    updateTask(tasks[i].copyWith(subtasks: list));
  }

  void setSubTaskStatus(String taskId, String subId, SubTaskStatus status) {
    final i = tasks.indexWhere((x) => x.id == taskId);
    if (i < 0) return;
    final t = tasks[i];
    final subs = t.subtasks.map((s) => s.id == subId ? s.copyWith(status: status) : s).toList();
    updateTask(t.copyWith(
      subtasks: subs,
      status: t.progress >= 1.0 ? TaskStatus.completed : t.computeStatus(DateTime.now()),
    ));
  }

  void startFocusOnSubTask(String taskId, String subId, int minutes) {
    pet.onFocusStart(minutes);
    final i = tasks.indexWhere((x) => x.id == taskId);
    if (i >= 0) {
      final before = tasks[i];
      final after = before.copyWith(status: TaskStatus.inProgress);
      tasks[i] = after;
      _petReactOnStatus(before, after);
      update();
    }
  }

  /// Called by the FocusTimer when user hits Start so the donut refreshes instantly.
  void markInProgress(String id) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = tasks[i];
    if (t.status != TaskStatus.inProgress) {
      tasks[i] = t.copyWith(status: TaskStatus.inProgress, updatedAt: DateTime.now());
      update();
    }
  }

  // ===== Dashboard buckets =====
  List<Task> get notStarted {
    final now = DateTime.now();
    return tasks.where((t) => t.computeStatus(now) == TaskStatus.notStarted).toList();
  }

  List<Task> get inProgress {
    final now = DateTime.now();
    return tasks.where((t) => t.computeStatus(now) == TaskStatus.inProgress).toList();
  }

  List<Task> get completed => tasks.where((t) => t.status == TaskStatus.completed).toList();

  List<Task> get late {
    final now = DateTime.now();
    return tasks.where((t) => t.computeStatus(now) == TaskStatus.late).toList();
  }

  // ===== Smart recommendations =====
  double _recommendScore(Task t, DateTime now) {
    // Priority weight
    final pri = switch (t.priority) {
      PriorityLevel.urgent => 4.0,
      PriorityLevel.high => 3.0,
      PriorityLevel.medium => 2.0,
      PriorityLevel.low => 1.0,
    };

    // Importance boost
    final imp = t.important ? 1.2 : 0.0;

    // Due proximity
    double due = 0;
    if (t.type == TaskType.singleDay && t.dueDateTime != null) {
      final mins = t.dueDateTime!.difference(now).inMinutes;
      if (mins <= 0) {
        due = 3.0; // overdue: strong push
      } else {
        due = (1440 - mins).clamp(0, 1440) / 1440 * 2.0; // within 24h
      }
    } else if (t.type == TaskType.ranged && t.dueDate != null) {
      final end = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59, 59);
      final mins = end.difference(now).inMinutes;
      if (mins <= 0) {
        due = 2.5;
      } else {
        due = (4320 - mins).clamp(0, 4320) / 4320 * 1.7; // 3-day window
      }
    }

    // Quick wins: short estimated tasks
    final int est =
        t.estimatedMinutes ?? t.subtasks.fold<int>(0, (a, s) => a + (s.estimatedMinutes ?? 0));
    final double quick = (est == 0)
        ? 0.3
        : (est <= 30)
            ? 0.6
            : (est <= 60)
                ? 0.3
                : 0.0;

    // Completed => bury
    final done = t.status == TaskStatus.completed ? -999.0 : 0.0;

    return pri + imp + due + quick + done;
  }

  List<Task> recommended({int max = 5}) {
    final now = DateTime.now();
    final candidates = tasks.where((t) => t.status != TaskStatus.completed).toList();
    candidates.sort((a, b) => _recommendScore(b, now).compareTo(_recommendScore(a, now)));
    return candidates.take(max).toList();
  }

  // ===== Notifications (local) =====
  void _scheduleAllNotifications(Task t) {
    notifier.cancelForTask(t.id);
    final now = DateTime.now();

    if (t.type == TaskType.singleDay && t.dueDateTime != null) {
      // Due reminders
      if (t.notify.remindBeforeDue) {
        final dt = t.dueDateTime!.subtract(t.notify.remindBeforeDueOffset);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(t.id, 'dueSoon', dt, _msgDueSoon(t), payload: t.id);
        }
      }
      if (t.notify.remindOnDue) {
        final dt = t.dueDateTime!;
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(t.id, 'dueNow', dt, _msgDueNow(t), payload: t.id);
        }
      }
      // Today nudges
      if (t.isDueToday(now) && t.notify.repeatWhenToday != RepeatGranularity.none) {
        if (t.notify.repeatWhenToday == RepeatGranularity.hour) {
          notifier.scheduleHourly(t.id, 'todayNudge', t.notify.repeatInterval, _msgToday(t),
              payload: t.id);
        } else if (t.notify.repeatWhenToday == RepeatGranularity.day) {
          notifier.scheduleDaily(
            t.id,
            'todayNudgeDaily',
            _msgToday(t),
            hour: t.notify.dailyHour ?? 9,
            minute: t.notify.dailyMinute ?? 0,
            payload: t.id,
          );
        }
      }
    } else if (t.type == TaskType.ranged && t.startDate != null && t.dueDate != null) {
      // Start reminders
      if (t.notify.remindBeforeStart) {
        final dt = t.startDate!.subtract(t.notify.remindBeforeStartOffset);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(t.id, 'startSoon', dt, _msgStartSoon(t), payload: t.id);
        }
      }
      if (t.notify.remindOnStart) {
        final dt = DateTime(t.startDate!.year, t.startDate!.month, t.startDate!.day, 8, 0);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(t.id, 'startToday', dt, _msgStartToday(t), payload: t.id);
        }
      }
      // Due reminders
      if (t.notify.remindBeforeDue) {
        final dt = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59)
            .subtract(t.notify.remindBeforeDueOffset);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(t.id, 'dueSoon', dt, _msgDueSoon(t), payload: t.id);
        }
      }
      if (t.notify.remindOnDue) {
        final dt = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day, 23, 59);
        if (dt.isAfter(now)) {
          notifier.scheduleOneShot(t.id, 'dueToday', dt, _msgDueNow(t), payload: t.id);
        }
      }
      // Today nudges when within the range
      if (!_isBeforeDay(now, t.startDate!) && !_isAfterDay(now, t.dueDate!)) {
        if (t.notify.repeatWhenToday == RepeatGranularity.hour) {
          notifier.scheduleHourly(t.id, 'todayNudge', t.notify.repeatInterval, _msgToday(t),
              payload: t.id);
        } else if (t.notify.repeatWhenToday == RepeatGranularity.day) {
          notifier.scheduleDaily(
            t.id,
            'todayNudgeDaily',
            _msgToday(t),
            hour: t.notify.dailyHour ?? 9,
            minute: t.notify.dailyMinute ?? 0,
            payload: t.id,
          );
        }
      }
    }
  }

  String _msgStartSoon(Task t) => "‘${t.title}’ starts soon. Plan your first session.";
  String _msgStartToday(Task t) => "‘${t.title}’ starts today. Kick off with 25 min!";
  String _msgDueSoon(Task t) => "‘${t.title}’ due soon. Wrap up remaining subtasks.";
  String _msgDueNow(Task t) => "‘${t.title}’ due today. Final push!";
  String _msgToday(Task t) => "Stay on track: ‘${t.title}’. Start a focus timer.";

  bool _isBeforeDay(DateTime a, DateTime b) {
    final bb = DateTime(b.year, b.month, b.day);
    final aa = DateTime(a.year, a.month, a.day);
    return aa.isBefore(bb);
  }

  bool _isAfterDay(DateTime a, DateTime b) {
    final bb = DateTime(b.year, b.month, b.day, 23, 59, 59);
    return a.isAfter(bb);
  }

  void _petReactOnStatus(Task before, Task after) {
    final now = DateTime.now();
    // Became late?
    final wasLate = before.computeStatus(now) == TaskStatus.late;
    final isLate = after.computeStatus(now) == TaskStatus.late;
    if (!wasLate && isLate) {
      pet.onTaskLate();
      return;
    }
    // Started?
    final wasNotStarted = before.computeStatus(now) == TaskStatus.notStarted;
    final nowInProgress = after.computeStatus(now) == TaskStatus.inProgress;
    if (wasNotStarted && nowInProgress) pet.onTaskStarted();
  }

  // ===== Demo seed (priority + importance + estimate) =====
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
      final important = (i % 3 != 0); // ~66% important
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
        subtasks: isSingle
            ? const []
            : [
                SubTask(id: 's_${uid}_1', title: 'Read', estimatedMinutes: 30),
                SubTask(id: 's_${uid}_2', title: 'Notes', estimatedMinutes: 30),
                SubTask(id: 's_${uid}_3', title: 'Practice', estimatedMinutes: 30),
              ],
      );
      addTask(t);
    }
  }
}
