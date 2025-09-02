// lib/pages/group_tasks_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/taskController.dart';
import '../models/task.dart';

class GroupTasksPage extends StatelessWidget {
  final String category;
  final TaskController taskC;
  
  const GroupTasksPage({super.key, required this.category, required this.taskC, required userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: Obx(() {
        final list = taskC.tasks.where((t) => t.category == category).toList();
        if (list.isEmpty) return const Center(child: Text('No tasks here yet'));
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final t = list[i];
            return ListTile(
              title: Text(t.title),
              subtitle: t.dueDate != null ? Text('Due ${t.dueDate!.toLocal().toString().split(' ').first}') : null,
              trailing: _StatusChip(status: t.status),
              onTap: () {
                // navigate to details or toggle complete, etc.
              },
            );
          },
        );
      }),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    late final Color c;
    late final String text;
    switch (status) {
      case TaskStatus.done:    c = Colors.green; text = 'Done'; break;
      case TaskStatus.overdue: c = Colors.red;   text = 'Overdue'; break;
      default:                 c = Colors.orange; text = 'Pending';
    }
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: c,
    );
  }
}
