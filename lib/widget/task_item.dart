import 'package:flutter/material.dart';

class TaskItem extends StatelessWidget {
  final String title;
  final bool completed;
  final String subtitle; // e.g., "⭐3  🔥4  • study"
  final VoidCallback onFocusTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const TaskItem({
    super.key,
    required this.title,
    required this.completed,
    required this.subtitle,
    required this.onFocusTap,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(title + subtitle),
      background: Container(color: Colors.redAccent),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: Checkbox(value: completed, onChanged: (_) => onToggle()),
        title: GestureDetector(
          onTap: onFocusTap,           // 👈 tap middle → focus
          child: Text(
            title,
            style: TextStyle(
              decoration: completed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        subtitle: Text(subtitle),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (c) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
