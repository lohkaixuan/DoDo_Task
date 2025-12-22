// lib/screens/focus_timer_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controller/taskController.dart';
import '../controller/petController.dart';
import '../models/task.dart';
import '../widgets/pad.dart';
import '../widgets/pet_header.dart';
import '../services/notification_service.dart';
import 'package:collection/collection.dart';


class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});
  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

enum _Phase { focus, shortBreak, longBreak }

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  // Controllers/services
  late final TaskController tc;
  late final PetController pet;
  late final NotificationService notifier;

  // Route args
  String? taskId;
  String? subTaskId;

  // Pomodoro prefs (default – may be overridden by task)
  int pomoMin = 25;
  int shortBreakMin = 5;
  int longBreakEvery = 4;

  // Timer state
  _Phase phase = _Phase.focus;
  int sessionCount = 0;
  Duration remaining = const Duration(minutes: 25);
  Timer? _ticker;
  bool running = false;

  // Preventive cache for remaining focus time when skipping breaks
  Duration? _focusRemainCache;

  // Ongoing local notification state
  static const int _notifId = 777;
  int _lastNotifiedMinute = -1;

  // Convenience getters
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
    this.taskId = args['taskId'] as String?;
    subTaskId = args['subTaskId'] as String?; // ✅ 如果你未来也想跳到某个 subtask

    final task = _task;
    if (task != null) {
      // per-task focus prefs
      pomoMin = task.focusPrefs.pomodoroMinutes;
      shortBreakMin = task.focusPrefs.shortBreakMinutes;
      longBreakEvery = task.focusPrefs.longBreakEvery;

      // choose initial session length using remaining estimate if available
      final rem = task.remainingEstimatedMinutes;
      final startMin = rem > 0 ? (rem >= 25 ? 25 : rem) : pomoMin;
      remaining = Duration(minutes: startMin);
    } else {
      remaining = Duration(minutes: pomoMin);
    }
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

    // Mark the task active so dashboard donut updates immediately
    if (taskId != null) {
      // requires TaskController.markInProgress()
      tc.markInProgress(taskId!);
    }

    pet.onFocusStart( );
    _notifyOngoing(); // show first sticky notification

    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (remaining.inSeconds <= 1) {
        _ticker?.cancel();
        _onPhaseCompleted();
      } else {
        setState(() => remaining -= const Duration(seconds: 1));
        pet.onFocusAccumulate(1);
        _notifyOngoing(); // refresh every ~minute
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
      remaining = Duration(minutes: pomoMin);
      _lastNotifiedMinute = -1;
      _focusRemainCache = null;
    });
  }

  void _nextPhase() {
    final cycles = sessionCount;
    if (phase == _Phase.focus) {
      final isLong = longBreakEvery > 0 && cycles % longBreakEvery == 0;
      phase = isLong ? _Phase.longBreak : _Phase.shortBreak;
      remaining = Duration(minutes: isLong ? (shortBreakMin * 2) : shortBreakMin);
    } else {
      phase = _Phase.focus;
      remaining = Duration(minutes: pomoMin);
    }
    setState(() {});
  }

  void _onPhaseCompleted() {
    if (phase == _Phase.focus) {
      sessionCount += 1;
      _logFocusMinutes(pomoMin);
      pet.addExp(5);
      _snack('Nice!', 'Focus session done (${pomoMin}m).');
      _focusRemainCache = null; // preventive next session estimate cache
    } else if (phase == _Phase.shortBreak) {
      _snack('Break done', 'Back to focus!');
    } else {
      _snack('Great!', 'Long break complete.');
    }
    notifier.cancelId(_notifId); // stop sticky notification for this phase
    _nextPhase();
    running = false;
    setState(() {});
  }

  //skip button handler
  void _skip() {
  _ticker?.cancel();
  running = false;
  notifier.cancelId(_notifId); // if not using notification can remove this line

  if (phase == _Phase.focus) {
    // from Focus jump to Break：clear cache, go to next phase
    _focusRemainCache = remaining;

    final isLong = longBreakEvery > 0 && sessionCount % longBreakEvery == 0;
    setState(() {
      phase = isLong ? _Phase.longBreak : _Phase.shortBreak;
      remaining = Duration(minutes: isLong ? (shortBreakMin * 2) : shortBreakMin);
    });
  } else {
    // from Break back to Focus：recovery cache；if not use back default focus time
    final r = _focusRemainCache;
    setState(() {
      phase = _Phase.focus;
      remaining = (r != null && r.inSeconds > 2)
          ? r
          : Duration(minutes: pomoMin);
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

  // ---- Notification helper ----
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

  // ---- UI helpers ----

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
        t, m,
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
            // Pet header on top
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
                    Text(
                      info,
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
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

// Simple dial that shows MM:SS
class _TimerDial extends StatelessWidget {
  final Duration remaining;
  const _TimerDial({required this.remaining});

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    // show total minutes (can exceed 59) and seconds remainder
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
