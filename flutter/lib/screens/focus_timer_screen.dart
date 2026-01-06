// ==================================================
// Program Name   : focus_timer_screen.dart
// Purpose        : Provide focus timer functionality to support productivity sessions, break intervals, and focus duration tracking.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 30 August 2025
// Last Modified  : 10 December 2025
// ==================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:collection/collection.dart';
import 'package:v3/controller/petController.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/models/task.dart';
import 'package:v3/services/notification_service.dart';
import 'package:v3/widgets/pad.dart';
import 'package:v3/widgets/pet_header.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});
  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

enum _Phase { focus, shortBreak, longBreak }

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  late final TaskController tc;
  late final PetController pet;
  late final NotificationService notifier;

  String? taskId;
  String? subTaskId;

  // Task prefs
  int pomoMin = 25;            // configured focus minutes (per task)
  int focusSessionMin = 25;    // THIS SCREEN's focus duration (what we always return to)
  int shortBreakMin = 5;
  int longBreakEvery = 4;

  // Timer state
  _Phase phase = _Phase.focus;
  int sessionCount = 0; // completed focus sessions count
  Duration remaining = const Duration(minutes: 25);
  Timer? _ticker;
  bool running = false;

  // Cache remaining focus time when user skips focus -> break and wants to come back
  Duration? _focusRemainCache;

  // Ongoing local notification state
  static const int _notifId = 777;
  int _lastNotifiedMinute = -1;

  Task? get _task =>
      taskId == null ? null : tc.tasks.firstWhereOrNull((t) => t.id == taskId);
  SubTask? get _subtask => subTaskId == null
      ? null
      : _task?.subtasks.firstWhereOrNull((s) => s.id == subTaskId);

  @override
  void initState() {
    super.initState();
    tc = Get.find<TaskController>();
    pet = Get.find<PetController>();
    notifier = Get.find<NotificationService>();

    final args = Get.arguments as Map? ?? {};
    taskId = args['taskId'] as String?;
    subTaskId = args['subTaskId'] as String?;

    final task = _task;
    if (task != null) {
      pomoMin = task.focusPrefs.pomodoroMinutes;
      shortBreakMin = task.focusPrefs.shortBreakMinutes;
      longBreakEvery = task.focusPrefs.longBreakEvery;

      // decide this screen's focus session length
      final rem = task.remainingEstimatedMinutes;
      focusSessionMin = (rem > 0) ? (rem >= pomoMin ? pomoMin : rem) : pomoMin;
    } else {
      // no task => just use configured/default
      focusSessionMin = pomoMin;
    }

    phase = _Phase.focus;
    remaining = Duration(minutes: focusSessionMin);

    debugPrint("🔥 pomoMin=$pomoMin focusSessionMin=$focusSessionMin taskId=$taskId task=${_task?.title}");

  }

  @override
  void dispose() {
    _ticker?.cancel();
    notifier.cancelId(_notifId);
    super.dispose();
  }

  // ---- Timer control ----

  void _start() {
    if (running) return;
    setState(() => running = true);

    if (taskId != null) tc.markInProgress(taskId!);

    pet.onFocusStart();
    _notifyOngoing();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (remaining.inSeconds <= 1) {
        _ticker?.cancel();
        _onPhaseCompleted();
      } else {
        setState(() => remaining -= const Duration(seconds: 1));
        pet.onFocusAccumulate(1);
        _notifyOngoing();
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    pet.onFocusPauseOrBreak();
    notifier.cancelId(_notifId);
    setState(() => running = false);
  }

  void _reset() {
    _ticker?.cancel();
    pet.onFocusPauseOrBreak();
    notifier.cancelId(_notifId);

    setState(() {
      running = false;
      phase = _Phase.focus;
      remaining = Duration(minutes: focusSessionMin); // ✅ not pomoMin
      _lastNotifiedMinute = -1;
      _focusRemainCache = null;
    });
  }

  void _nextPhase() {
    // NOTE: sessionCount already increased when a focus completes.
    if (phase == _Phase.focus) {
      final isLong = longBreakEvery > 0 && (sessionCount % longBreakEvery == 0);
      phase = isLong ? _Phase.longBreak : _Phase.shortBreak;
      remaining = Duration(minutes: isLong ? (shortBreakMin * 2) : shortBreakMin);
    } else {
      phase = _Phase.focus;
      remaining = Duration(minutes: focusSessionMin); // ✅ always return to chosen focus
    }
    setState(() {});
  }

  void _onPhaseCompleted() {
    if (phase == _Phase.focus) {
      sessionCount += 1;

      // ✅ log only once with focusSessionMin
      _logFocusMinutes(focusSessionMin);

      pet.addExp(5);
      _snack('Nice!', 'Focus session done (${focusSessionMin}m).');
      _focusRemainCache = null;
    } else if (phase == _Phase.shortBreak) {
      _snack('Break done', 'Back to focus!');
    } else {
      _snack('Great!', 'Long break complete.');
    }

    notifier.cancelId(_notifId);
    running = false;

    _nextPhase();
  }

  // Skip button
  void _skip() {
    _ticker?.cancel();
    running = false;
    notifier.cancelId(_notifId);

    if (phase == _Phase.focus) {
      // Focus -> Break: cache current remaining focus time
      _focusRemainCache = remaining;

      final isLong = longBreakEvery > 0 && (sessionCount % longBreakEvery == 0);
      setState(() {
        phase = isLong ? _Phase.longBreak : _Phase.shortBreak;
        remaining = Duration(minutes: isLong ? (shortBreakMin * 2) : shortBreakMin);
      });
    } else {
      // Break -> Focus: restore cached focus time, otherwise use focusSessionMin (NOT pomoMin)
      final r = _focusRemainCache;
      setState(() {
        phase = _Phase.focus;
        remaining = (r != null && r.inSeconds > 2)
            ? r
            : Duration(minutes: focusSessionMin); // ✅ not pomoMin
      });
    }
  }

  // Persist focus minutes into the task/subtask
  void _logFocusMinutes(int minutes) {
    final task = _task;
    if (task == null) return;

    if (subTaskId != null) {
      final subs = task.subtasks.map((s) {
        if (s.id == subTaskId) {
          final newSpent = s.focusMinutesSpent + minutes;
          final newStatus = s.status == SubTaskStatus.completed
              ? s.status
              : SubTaskStatus.inProgress;
          return s.copyWith(focusMinutesSpent: newSpent, status: newStatus);
        }
        return s;
      }).toList();

      tc.updateTask(task.copyWith(
        subtasks: subs,
        status: task.computeStatus(DateTime.now()),
      ));
    } else {
      if (task.status == TaskStatus.notStarted) {
        tc.updateTask(task.copyWith(status: TaskStatus.inProgress));
      }
    }
  }

  void _notifyOngoing() {
    final mins = remaining.inMinutes;
    if (mins != _lastNotifiedMinute) {
      _lastNotifiedMinute = mins;
      notifier.showFocusOngoing(
        id: _notifId,
        title: _title(),
        minutesLeft: mins,
      );
    }
  }

  String _title() {
    final task = _task;
    if (task == null) return 'Focus';
    if (_subtask == null) return task.title;
    return '${task.title} — ${_subtask!.title}';
  }

  String _rangeInfo() {
    final task = _task;
    if (task == null) return '—';
    final fmtDay = DateFormat('MMM d');
    final fmtDT = DateFormat('MMM d, HH:mm');

    if (task.type == TaskType.singleDay && task.dueDateTime != null) {
      return 'Due ${fmtDT.format(task.dueDateTime!)}';
    }
    if (task.type == TaskType.ranged && task.startDate != null && task.dueDate != null) {
      return '${fmtDay.format(task.startDate!)} → ${fmtDay.format(task.dueDate!)}';
    }
    return '—';
  }

  void _snack(String t, String m) => Get.snackbar(
        t,
        m,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

  @override
  Widget build(BuildContext context) {
    final info = _rangeInfo();

    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        actions: [
          Obx(() => Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('Pet: ${Get.find<PetController>().emotion.value}/100'),
                ),
              )),
          IconButton(onPressed: _reset, icon: const Icon(Icons.replay_rounded)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: padAll(context, h: 16, v: 12),
          children: [
            const PetHeader(),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      phase == _Phase.focus
                          ? 'Focus'
                          : (phase == _Phase.shortBreak ? 'Short break' : 'Long break'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(info, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                    const SizedBox(height: 20),

                    _TimerDial(remaining: remaining),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: running ? _pause : _start,
                          icon: Icon(running ? Icons.pause : Icons.play_arrow_rounded),
                          label: Text(running ? 'Pause' : 'Start'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _skip,
                          icon: const Icon(Icons.skip_next_outlined),
                          label: const Text('Skip'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Sessions completed: $sessionCount'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerDial extends StatelessWidget {
  final Duration remaining;
  const _TimerDial({required this.remaining});

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    final mm = two(remaining.inMinutes);
    final ss = two(remaining.inSeconds.remainder(60));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Center(
        child: Text(
          '$mm:$ss',
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
    );
  }
}
