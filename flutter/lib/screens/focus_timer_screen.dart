import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/task.dart';
import '../controller/taskController.dart';
import '../widgets/pet_header.dart';

class FocusTimerScreen extends StatelessWidget {
  final Task task;
  final bool autoStart;
  const FocusTimerScreen({super.key, required this.task, this.autoStart = true});

  String _modeImage(TaskMode m) => switch (m) {
        TaskMode.study    => 'assets/study.png',
        TaskMode.wellness => 'assets/wellness.png',
        TaskMode.family   => 'assets/family.png',
        TaskMode.personal => 'assets/logo.png',
      };

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TaskController>();

    // auto-start when opened from a list
    if (autoStart && c.activeTimerTaskId.value != task.id && !c.timerActive.value) {
      c.startFocus(task);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Focus: ${task.title}', overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Session length',
            onSelected: (m) {
              c.sessionMinutes.value = m;
              if (c.activeTimerTaskId.value == task.id) {
                c.startFocus(task, minutes: m); // restart with new length
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 15, child: Text('15 min')),
              PopupMenuItem(value: 25, child: Text('25 min')),
              PopupMenuItem(value: 45, child: Text('45 min')),
            ],
            icon: const Icon(Icons.timer),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Mode-specific sprite + status
          PetHeader(
            imageOverride: _modeImage(task.mode),
            statusOverride: 'Focus mode: ${task.mode.name}',
          ),
          Expanded(
            child: Center(
              child: Obx(() {
                final isActive   = c.timerActive.value && c.activeTimerTaskId.value == task.id;
                final isThisTask = c.activeTimerTaskId.value == task.id;
                final time = c.mmss;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(time,
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        )),
                    const SizedBox(height: 16),
                    Text(
                      isActive ? 'Focusing…' : (isThisTask ? 'Paused' : 'Ready'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (!isActive && (!isThisTask || c.secondsLeft.value == 0))
                          FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start'),
                            onPressed: () => c.startFocus(task),
                          ),
                        if (isActive)
                          FilledButton.icon(
                            icon: const Icon(Icons.pause),
                            label: const Text('Pause'),
                            onPressed: c.pauseFocus,
                          ),
                        if (!isActive && isThisTask && c.secondsLeft.value > 0)
                          FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Resume'),
                            onPressed: c.resumeFocus,
                          ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          onPressed: c.stopFocus,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Session: ${c.sessionMinutes.value} min'),
                    if (task.estimateMinutes > 0)
                      Text('Estimate: ${task.estimateMinutes} min',
                          style: TextStyle(color: Colors.grey.shade600)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
