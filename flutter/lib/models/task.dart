// lib/models/task.dart
import 'dart:convert';

enum TaskType { singleDay, ranged } // single dueDateTime vs start+due
enum TaskStatus { notStarted, inProgress, completed, late, archived }
enum RepeatGranularity { none, minute, hour, day } // for reminder cadence

// NEW: Overall priority for the task
enum PriorityLevel { low, medium, high, urgent }

class FocusTimerPrefs {
  final int pomodoroMinutes; // e.g., 25
  final int shortBreakMinutes; // e.g., 5
  final int longBreakEvery; // e.g., 4 pomodoros
  final bool notificationsEnabled;

  const FocusTimerPrefs({
    this.pomodoroMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakEvery = 4,
    this.notificationsEnabled = true,
  });

  FocusTimerPrefs copyWith({
    int? pomodoroMinutes,
    int? shortBreakMinutes,
    int? longBreakEvery,
    bool? notificationsEnabled,
  }) =>
      FocusTimerPrefs(
        pomodoroMinutes: pomodoroMinutes ?? this.pomodoroMinutes,
        shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
        longBreakEvery: longBreakEvery ?? this.longBreakEvery,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );

  Map<String, dynamic> toJson() => {
        'pomodoroMinutes': pomodoroMinutes,
        'shortBreakMinutes': shortBreakMinutes,
        'longBreakEvery': longBreakEvery,
        'notificationsEnabled': notificationsEnabled,
      };

  factory FocusTimerPrefs.fromJson(Map<String, dynamic> json) =>
      FocusTimerPrefs(
        pomodoroMinutes: json['pomodoroMinutes'] ?? 25,
        shortBreakMinutes: json['shortBreakMinutes'] ?? 5,
        longBreakEvery: json['longBreakEvery'] ?? 4,
        notificationsEnabled: json['notificationsEnabled'] ?? true,
      );
}

class NotificationPrefs {
  /// Remind before/at start (for ranged tasks)
  final bool remindBeforeStart;
  final Duration remindBeforeStartOffset; // e.g., 24h before start

  /// Remind at start time/date
  final bool remindOnStart;

  /// Remind before/at due
  final bool remindBeforeDue;
  final Duration remindBeforeDueOffset; // e.g., 2h before due
  final bool remindOnDue;

  /// For “today” nudges when a task date == today (e.g., hourly or daily)
  final RepeatGranularity repeatWhenToday; // none/hour/day
  final int repeatInterval;                // every N hours or N days

  /// NEW: exact local time for the daily nudge (when repeatWhenToday == day)
  /// If null, the app will fall back to (9:00).
  final int? dailyHour;                    // 0–23
  final int? dailyMinute;                  // 0–59

  const NotificationPrefs({
    this.remindBeforeStart = true,
    this.remindBeforeStartOffset = const Duration(hours: 24),
    this.remindOnStart = true,
    this.remindBeforeDue = true,
    this.remindBeforeDueOffset = const Duration(hours: 2),
    this.remindOnDue = true,
    this.repeatWhenToday = RepeatGranularity.none,
    this.repeatInterval = 1,
    this.dailyHour,
    this.dailyMinute,
  });

  NotificationPrefs copyWith({
    bool? remindBeforeStart,
    Duration? remindBeforeStartOffset,
    bool? remindOnStart,
    bool? remindBeforeDue,
    Duration? remindBeforeDueOffset,
    bool? remindOnDue,
    RepeatGranularity? repeatWhenToday,
    int? repeatInterval,
    int? dailyHour,
    int? dailyMinute,
  }) =>
      NotificationPrefs(
        remindBeforeStart: remindBeforeStart ?? this.remindBeforeStart,
        remindBeforeStartOffset:
            remindBeforeStartOffset ?? this.remindBeforeStartOffset,
        remindOnStart: remindOnStart ?? this.remindOnStart,
        remindBeforeDue: remindBeforeDue ?? this.remindBeforeDue,
        remindBeforeDueOffset:
            remindBeforeDueOffset ?? this.remindBeforeDueOffset,
        remindOnDue: remindOnDue ?? this.remindOnDue,
        repeatWhenToday: repeatWhenToday ?? this.repeatWhenToday,
        repeatInterval: repeatInterval ?? this.repeatInterval,
        dailyHour: dailyHour ?? this.dailyHour,
        dailyMinute: dailyMinute ?? this.dailyMinute,
      );

  Map<String, dynamic> toJson() => {
        'remindBeforeStart': remindBeforeStart,
        'remindBeforeStartOffset': remindBeforeStartOffset.inMinutes,
        'remindOnStart': remindOnStart,
        'remindBeforeDue': remindBeforeDue,
        'remindBeforeDueOffset': remindBeforeDueOffset.inMinutes,
        'remindOnDue': remindOnDue,
        'repeatWhenToday': repeatWhenToday.name,
        'repeatInterval': repeatInterval,
        'dailyHour': dailyHour,
        'dailyMinute': dailyMinute,
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    RepeatGranularity gran;
    switch (json['repeatWhenToday']) {
      case 'hour':
        gran = RepeatGranularity.hour;
        break;
      case 'day':
        gran = RepeatGranularity.day;
        break;
      default:
        gran = RepeatGranularity.none;
    }
    return NotificationPrefs(
      remindBeforeStart: json['remindBeforeStart'] ?? true,
      remindBeforeStartOffset:
          Duration(minutes: (json['remindBeforeStartOffset'] ?? 1440)),
      remindOnStart: json['remindOnStart'] ?? true,
      remindBeforeDue: json['remindBeforeDue'] ?? true,
      remindBeforeDueOffset:
          Duration(minutes: (json['remindBeforeDueOffset'] ?? 120)),
      remindOnDue: json['remindOnDue'] ?? true,
      repeatWhenToday: gran,
      repeatInterval: json['repeatInterval'] ?? 1,
      dailyHour: json['dailyHour'],
      dailyMinute: json['dailyMinute'],
    );
  }
}

enum SubTaskStatus { notStarted, inProgress, completed, skipped }

class SubTask {
  final String id;
  final String title;
  final int? estimatedMinutes;
  final DateTime? dueDate; // optional per-subtask deadline
  final SubTaskStatus status;
  final int focusMinutesSpent;

  const SubTask({
    required this.id,
    required this.title,
    this.estimatedMinutes,
    this.dueDate,
    this.status = SubTaskStatus.notStarted,
    this.focusMinutesSpent = 0,
  });

  SubTask copyWith({
    String? id,
    String? title,
    int? estimatedMinutes,
    DateTime? dueDate,
    SubTaskStatus? status,
    int? focusMinutesSpent,
  }) =>
      SubTask(
        id: id ?? this.id,
        title: title ?? this.title,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        focusMinutesSpent: focusMinutesSpent ?? this.focusMinutesSpent,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'estimatedMinutes': estimatedMinutes,
        'dueDate': dueDate?.toIso8601String(),
        'status': status.name,
        'focusMinutesSpent': focusMinutesSpent,
      };

  factory SubTask.fromJson(Map<String, dynamic> json) => SubTask(
        id: json['id'],
        title: json['title'],
        estimatedMinutes: json['estimatedMinutes'],
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        status: SubTaskStatus.values.firstWhere(
          (e) => e.name == (json['status'] ?? 'notStarted'),
          orElse: () => SubTaskStatus.notStarted,
        ),
        focusMinutesSpent: json['focusMinutesSpent'] ?? 0,
      );
}

class Task {
  final String id;
  final String title;
  final String? description;

  final TaskType type;

  /// single-day: dueDateTime must be set
  final DateTime? dueDateTime;

  /// ranged: startDate & dueDate must be set (date-level granularity)
  final DateTime? startDate; // 00:00 local
  final DateTime? dueDate; // 23:59:59 local

  final String timezone; // e.g., "Asia/Kuala_Lumpur"

  /// Category & tags
  final String? category; // e.g., "Study"
  final List<String> tags; // e.g., ["Algorithm", "Exam"]

  /// Progress & status
  final TaskStatus status;
  final List<SubTask> subtasks;

  /// Focus timer prefs (used by pet widget nudges)
  final FocusTimerPrefs focusPrefs;

  /// Notification preferences
  final NotificationPrefs notify;

  /// NEW: planning fields
  final PriorityLevel priority;     // low/medium/high/urgent
  final bool important;             // Eisenhower "important?"
  final int? estimatedMinutes;      // whole-task estimate (minutes)

  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.dueDateTime,
    this.startDate,
    this.dueDate,
    this.timezone = 'Asia/Kuala_Lumpur',
    this.category,
    this.tags = const [],
    this.status = TaskStatus.notStarted,
    this.subtasks = const [],
    this.focusPrefs = const FocusTimerPrefs(),
    this.notify = const NotificationPrefs(),
    this.priority = PriorityLevel.medium,  // NEW default
    this.important = true,                 // NEW default
    this.estimatedMinutes,                 // NEW
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Derived properties
  bool get hasSubtasks => subtasks.isNotEmpty;

  int get completedSubtasks =>
      subtasks.where((s) => s.status == SubTaskStatus.completed).length;

  double get progress => subtasks.isEmpty
      ? (status == TaskStatus.completed ? 1.0 : 0.0)
      : completedSubtasks / subtasks.length;

  /// Minutes actually spent across subtasks
  int get spentMinutes =>
      subtasks.fold<int>(0, (a, s) => a + (s.focusMinutesSpent));

  /// If task-level `estimatedMinutes` is null, sum subtask estimates
  int get remainingEstimatedMinutes {
    final est = estimatedMinutes ??
        subtasks.fold<int>(0, (a, s) => a + (s.estimatedMinutes ?? 0));
    final rem = est - spentMinutes;
    return rem < 0 ? 0 : rem;
  }

  bool isDueToday(DateTime now) {
    if (type == TaskType.singleDay && dueDateTime != null) {
      return _isSameDate(dueDateTime!, now);
    }
    if (type == TaskType.ranged && dueDate != null) {
      return _isSameDate(dueDate!, now);
    }
    return false;
  }

  bool get isRanged => type == TaskType.ranged;

  TaskStatus computeStatus(DateTime now) {
    if (status == TaskStatus.completed || status == TaskStatus.archived) {
      return status;
    }
    if (type == TaskType.singleDay) {
      if (dueDateTime == null) return status;
      if (now.isAfter(dueDateTime!)) return TaskStatus.late;
      return _inferActive() ? TaskStatus.inProgress : TaskStatus.notStarted;
    } else {
      if (dueDate == null || startDate == null) return status;
      if (_isPastEndOfDay(now, dueDate!)) return TaskStatus.late;
      if (!_isBeforeStartOfDay(now, startDate!)) {
        return _inferActive() ? TaskStatus.inProgress : TaskStatus.notStarted;
      }
      return TaskStatus.notStarted;
    }
  }

  bool _inferActive() =>
      status == TaskStatus.inProgress ||
      subtasks.any((s) => s.status == SubTaskStatus.inProgress);

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isBeforeStartOfDay(DateTime now, DateTime day) {
    final t = DateTime(day.year, day.month, day.day, 0, 0, 0);
    return now.isBefore(t);
  }

  static bool _isPastEndOfDay(DateTime now, DateTime day) {
    final t = DateTime(day.year, day.month, day.day, 23, 59, 59);
    return now.isAfter(t);
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskType? type,
    DateTime? dueDateTime,
    DateTime? startDate,
    DateTime? dueDate,
    String? timezone,
    String? category,
    List<String>? tags,
    TaskStatus? status,
    List<SubTask>? subtasks,
    FocusTimerPrefs? focusPrefs,
    NotificationPrefs? notify,
    PriorityLevel? priority,     // NEW
    bool? important,             // NEW
    int? estimatedMinutes,       // NEW
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        type: type ?? this.type,
        dueDateTime: dueDateTime ?? this.dueDateTime,
        startDate: startDate ?? this.startDate,
        dueDate: dueDate ?? this.dueDate,
        timezone: timezone ?? this.timezone,
        category: category ?? this.category,
        tags: tags ?? this.tags,
        status: status ?? this.status,
        subtasks: subtasks ?? this.subtasks,
        focusPrefs: focusPrefs ?? this.focusPrefs,
        notify: notify ?? this.notify,
        priority: priority ?? this.priority,           // NEW
        important: important ?? this.important,        // NEW
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes, // NEW
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'dueDateTime': dueDateTime?.toIso8601String(),
        'startDate': startDate?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'timezone': timezone,
        'category': category,
        'tags': tags,
        'status': status.name,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'focusPrefs': focusPrefs.toJson(),
        'notify': notify.toJson(),
        // NEW:
        'priority': priority.name,
        'important': important,
        'estimatedMinutes': estimatedMinutes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        type: (json['type'] == 'ranged') ? TaskType.ranged : TaskType.singleDay,
        dueDateTime: json['dueDateTime'] != null
            ? DateTime.parse(json['dueDateTime'])
            : null,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'])
            : null,
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        timezone: json['timezone'] ?? 'Asia/Kuala_Lumpur',
        category: json['category'],
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        status: TaskStatus.values.firstWhere(
          (e) => e.name == (json['status'] ?? 'notStarted'),
          orElse: () => TaskStatus.notStarted,
        ),
        subtasks: ((json['subtasks'] as List?) ?? [])
            .map((e) => SubTask.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        focusPrefs: json['focusPrefs'] != null
            ? FocusTimerPrefs.fromJson(
                Map<String, dynamic>.from(json['focusPrefs']))
            : const FocusTimerPrefs(),
        notify: json['notify'] != null
            ? NotificationPrefs.fromJson(
                Map<String, dynamic>.from(json['notify']))
            : const NotificationPrefs(),
        priority: _priorityFrom(json['priority']),
        important: json['important'] ?? true,
        estimatedMinutes: json['estimatedMinutes'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
      );

  static PriorityLevel _priorityFrom(dynamic v) {
    final s = (v ?? 'medium').toString();
    return PriorityLevel.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PriorityLevel.medium,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
