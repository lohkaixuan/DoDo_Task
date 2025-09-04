import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controller/taskController.dart';
import '../models/task.dart';
import '../screens/focus_timer_screen.dart';
import '../screens/add_update_task.dart';

/// -------- helpers
String _two(int v) => v.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${_two(d.month)}/${_two(d.day)}';
String fmtDateTime(DateTime d) =>
    '${_two(d.month)}/${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

String minutesHM(int? minutes) {
  final m = (minutes ?? 0).clamp(0, 1 << 30);
  final h = m ~/ 60;
  final mm = m % 60;
  if (h == 0) return '${mm}m';
  return '${h}h ${mm}m';
}

Widget _swipeBg({
  required bool alignRight,
  required String label,
  required IconData icon,
  Color? color,
}) {
  final child = Row(
    mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
    children: [
      if (!alignRight) const SizedBox(width: 12),
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      if (alignRight) const SizedBox(width: 12),
    ],
  );
  return Container(
    color: color ?? (alignRight ? Colors.red : Colors.green),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
    child: child,
  );
}

/// -------- tile
class TaskListTile extends StatelessWidget {
  const TaskListTile({
    super.key,
    required this.task,
    this.compact = false,
  });

  final Task task;
  final bool compact;

  bool get _isDone => task.status == TaskStatus.completed;

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TaskController>();
    final radius = BorderRadius.circular(14);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          // complete or undo
          _toggleComplete(tc);
          return false; // keep the tile (we handled it)
        } else {
          final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete task?'),
                  content: Text('Remove “${task.title}”?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              ) ??
              false;
          if (ok) {
            try {
              tc.notifier.cancelForTask(task.id);
            } catch (_) {}
            tc.tasks.removeWhere((x) => x.id == task.id);
            tc.update();
          }
          return ok;
        }
      },
      background: _swipeBg(
        alignRight: false,
        label: _isDone ? 'Undo' : 'Complete',
        icon: _isDone ? Icons.undo_rounded : Icons.check_circle,
        color: _isDone ? Colors.blue : Colors.green,
      ),
      secondaryBackground:
          _swipeBg(alignRight: true, label: 'Delete', icon: Icons.delete),

      child: Opacity(
        opacity: _isDone ? 0.6 : 1.0, // dim when done
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: radius),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            borderRadius: radius,
            onTap: () => _startFocus(task),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 8 : 10,
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _isDone,
                    onChanged: (_) => _toggleComplete(tc),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _TitleAndMeta(task: task, compact: compact)),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'focus':
                          _startFocus(task);
                          break;
                        case 'edit':
                          _edit(task);
                          break;
                        case 'toggle':
                          _toggleComplete(tc);
                          break;
                        case 'delete':
                          try {
                            tc.notifier.cancelForTask(task.id);
                          } catch (_) {}
                          tc.tasks.removeWhere((x) => x.id == task.id);
                          tc.update();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'focus', child: Text('Start focus')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(_isDone ? 'Mark as not done' : 'Mark complete'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleComplete(TaskController tc) {
    if (_isDone) {
      // undo -> notStarted (or infer)
      tc.updateTask(task.copyWith(status: TaskStatus.notStarted));
    } else {
      tc.completeTask(task.id);
    }
  }

  void _startFocus(Task t) {
    Get.to(() => const FocusTimerScreen(), arguments: {'taskId': t.id});
  }

  void _edit(Task t) {
    final tc = Get.find<TaskController>();
    showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      builder: (_) => AddUpdateTaskSheet(controller: tc, initial: t),
    );
  }
}

class _TitleAndMeta extends StatelessWidget {
  const _TitleAndMeta({required this.task, required this.compact});
  final Task task;
  final bool compact;

  bool get _isDone => task.status == TaskStatus.completed;

  @override
  Widget build(BuildContext context) {
    final isSingle = task.type == TaskType.singleDay;
    final due = isSingle ? task.dueDateTime : task.dueDate;
    final start = task.startDate;

    final titleStyle = TextStyle(
      fontWeight: FontWeight.w600,
      decoration: _isDone ? TextDecoration.lineThrough : TextDecoration.none,
      color: _isDone ? Colors.grey.shade700 : null,
    );

    final metaColor = _isDone ? Colors.grey : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if ((task.category ?? '').isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.folder_open, size: 16, color: metaColor),
                const SizedBox(width: 4),
                Text(task.category!, style: TextStyle(color: metaColor)),
              ]),
            if (isSingle && due != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule, size: 16, color: metaColor),
                const SizedBox(width: 4),
                Text(fmtDateTime(due), style: TextStyle(color: metaColor)),
              ]),
            if (!isSingle && start != null && due != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event, size: 16, color: metaColor),
                const SizedBox(width: 4),
                Text('${fmtDate(start)} → ${fmtDate(due)}',
                    style: TextStyle(color: metaColor)),
              ]),
            if (!compact && (task.estimatedMinutes ?? 0) > 0)
              Text(minutesHM(task.estimatedMinutes),
                  style: TextStyle(color: metaColor)),
          ],
        ),
      ],
    );
  }
}
