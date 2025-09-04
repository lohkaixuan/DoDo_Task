import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controller/taskController.dart';
import '../models/task.dart';
import '../widgets/task_list_tile.dart';
import '../widgets/pad.dart';

class TaskToday extends StatelessWidget {
  const TaskToday({super.key});

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isInRange(DateTime today, DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return !today.isBefore(s) && !today.isAfter(e);
  }

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TaskController>();
    final now = DateTime.now();

    return SafeArea(
      child: Obx(() {
        final items = tc.tasks.where((t) {
          if (t.status == TaskStatus.archived) return false;
          if (t.type == TaskType.singleDay && t.dueDateTime != null) {
            return _isSameDate(t.dueDateTime!, now);
          }
          if (t.type == TaskType.ranged && t.startDate != null && t.dueDate != null) {
            return _isInRange(now, t.startDate!, t.dueDate!);
          }
          return false;
        }).toList()
          ..sort((a, b) {
            final ad = a.dueDateTime ?? a.dueDate ?? DateTime(3000);
            final bd = b.dueDateTime ?? b.dueDate ?? DateTime(3000);
            return ad.compareTo(bd);
          });

        return ListView(
          padding: padAll(context, h: 16, v: 16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No tasks for today. Enjoy the day!')),
              )
            else
              ...items.map((t) => TaskListTile(task: t)),
            const SizedBox(height: 100), // keeps above bottom nav/FAB
          ],
        );
      }),
    );
  }
}
