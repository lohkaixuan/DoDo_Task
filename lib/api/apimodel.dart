
class ApiResponse {
  final String status;
  final String message;
  final dynamic data; // or make a typed model

  ApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'], // can be Map/List/String/null
    );
  }
}

class TaskDto {
  final String id;
  final String title;
  final bool completed;

  /// 1..5 (5 = highest)
  final int priority;
  /// 1..5 (5 = most important)
  final int importance;

  /// 'study' | 'personal' | 'family'
  final String mode;

  final int? estimateMins;
  final DateTime? due;
  final String? notes;

  TaskDto({
    required this.id,
    required this.title,
    this.completed = false,
    this.priority = 3,
    this.importance = 3,
    this.mode = 'study',
    this.estimateMins,
    this.due,
    this.notes,
  });

  TaskDto copyWith({
    String? title,
    bool? completed,
    int? priority,
    int? importance,
    String? mode,
    int? estimateMins,
    DateTime? due,
    String? notes,
  }) {
    return TaskDto(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      importance: importance ?? this.importance,
      mode: mode ?? this.mode,
      estimateMins: estimateMins ?? this.estimateMins,
      due: due ?? this.due,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'priority': priority,
        'importance': importance,
        'mode': mode,
        'estimateMins': estimateMins,
        'due': due?.toIso8601String(),
        'notes': notes,
      };

  factory TaskDto.fromJson(Map<String, dynamic> json) => TaskDto(
        id: json['id'].toString(),
        title: json['title'] ?? '',
        completed: json['completed'] == true,
        priority: (json['priority'] ?? 3) as int,
        importance: (json['importance'] ?? 3) as int,
        mode: (json['mode'] ?? 'study').toString(),
        estimateMins: json['estimateMins'],
        due: json['due'] != null ? DateTime.parse(json['due']) : null,
        notes: json['notes'],
      );
}
