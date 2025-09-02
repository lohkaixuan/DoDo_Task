// lib/widgets/task_group_tile.dart
import 'package:flutter/material.dart';

class TaskGroupTile extends StatelessWidget {
  final String title;
  final int count;
  final double completion; // 0..1
  final Color color;
  final VoidCallback onTap;

  const TaskGroupTile({
    super.key,
    required this.title,
    required this.count,
    required this.completion,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.folder_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text("$count Tasks", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                ],
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 44, height: 44,
                  child: CircularProgressIndicator(
                    value: completion.clamp(0.0, 1.0),
                    strokeWidth: 6,
                  ),
                ),
                Text("${(completion * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
