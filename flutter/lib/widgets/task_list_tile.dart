// ==================================================
// Program Name   : task_list_tile.dart
// Purpose        : Provide a reusable list tile widget to display task information including title, status, priority, and quick actions.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 22 August 2025
// Last Modified  : 12 December 2025
// ==================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/models/task.dart';
import 'package:v3/screens/add_update_task.dart';
import 'package:v3/screens/focus_timer_screen.dart';

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
    mainAxisAlignment:
        alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
    children: [
      if (!alignRight) const SizedBox(width: 12),
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
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
      key: Key(task.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        // 👉 逻辑 1：从左向右滑 (StartToEnd) -> 完成/撤销
        if (dir == DismissDirection.startToEnd) {
          _toggleComplete(tc);
          return false; // 不删除组件，只改状态
        }

        // 👉 逻辑 2：从右向左滑 (EndToStart) -> 删除
        else {
          final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete task?'),
                  content: Text('Remove “${task.title}”?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete')),
                  ],
                ),
              ) ??
              false;

          if (ok) {
            // ✅✅✅ 关键修复！直接调用 Controller 的删除方法！
            // 这会自动触发：1.本地删除 2.ID清洗 3.发送API请求
            tc.removeById(task.id);
          }
          return ok;
        }
      },

      // 🎨 视觉 1：从左向右滑的背景 (StartToEnd) -> 完成 (绿色/蓝色)
      background: _swipeBg(
        alignRight: false, // 图标在左边
        label: _isDone ? 'Undo' : 'Complete',
        icon: _isDone ? Icons.undo_rounded : Icons.check_circle,
        color: _isDone ? Colors.blue : Colors.green,
      ),

      // 🎨 视觉 2：从右向左滑的背景 (EndToStart) -> 删除 (红色)
      secondaryBackground: _swipeBg(
        alignRight: true, // 图标在右边
        label: 'Delete',
        icon: Icons.delete,
        color: Colors.red,
      ),

      child: Opacity(
        // ... 原封不动 ...
        opacity: _isDone ? 0.6 : 1.0,
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
                          // 这里的菜单点击删除也要改！
                          tc.removeById(task.id); // ✅ 换成这个
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'focus', child: Text('Start focus')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                            _isDone ? 'Mark as not done' : 'Mark complete'),
                      ),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
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
      // ❌ 之前是直接 updateTask
      // tc.updateTask(task.copyWith(status: TaskStatus.notStarted));

      // ✅ 现在改成调用撤销方法 (会扣钱)
      tc.undoComplete(task.id);
    } else {
      // 完成任务 (会加钱)
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
