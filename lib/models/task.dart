// lib/models/task.dart
enum TaskStatus { pending, done, overdue }

TaskStatus _statusFrom(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'done': return TaskStatus.done;
    case 'overdue': return TaskStatus.overdue;
    default: return TaskStatus.pending;
  }
}

class Task {
  final String id;
  final String userId;
  final String title;
  final String category; // Academic/Personal/Private
  final TaskStatus status;
  final DateTime? dueDate;
  final int? priority;
  final int? estimatedTime;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.status,
    this.dueDate,
    this.priority,
    this.estimatedTime,
  });

  factory Task.fromJson(Map<String, dynamic> j) {
    return Task(
      id: (j['task_id'] ?? j['id']).toString(),
      userId: j['user_id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      category: j['category']?.toString() ?? 'Personal',
      status: _statusFrom(j['status']?.toString()),
      dueDate: j['due_date'] != null ? DateTime.tryParse(j['due_date']) : null,
      priority: j['priority'] is int ? j['priority'] : int.tryParse('${j['priority'] ?? ''}'),
      estimatedTime: j['estimated_time'] is int ? j['estimated_time'] : int.tryParse('${j['estimated_time'] ?? ''}'),
    );
  }
}
