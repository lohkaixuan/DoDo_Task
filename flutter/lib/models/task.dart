// lib/models/task.dart

// Urgency/importance buckets
enum Eisenhower { q1UrgentImportant, q2Important, q3Urgent, q4Other }

// Lifestyle modes
enum TaskMode { study, wellness, family, personal }

class Task {
  final String id;
  final String title;
  final String? desc;
  final DateTime createdAt; // stored as UTC
  bool completed;

  // Scheduling / importance
  final DateTime? dueAt; // treat as UTC in storage
  final bool important;
  final int estimateMinutes;
  final int priority; // 1 (high) .. 5 (low) by convention

  // Mode
  final TaskMode mode;

  // History: when completed (nullable, UTC)
  DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    this.desc,
    DateTime? createdAt,
    this.completed = false,
    this.dueAt,
    this.important = false,
    this.estimateMinutes = 0,
    this.priority = 3,
    this.mode = TaskMode.personal,
    this.completedAt,
  }) : createdAt = (createdAt ?? DateTime.now()).toUtc();

  // ---------- JSON ----------

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'desc': desc,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'completed': completed,
        'dueAt': dueAt?.toUtc().toIso8601String(),
        'important': important,
        'estimateMinutes': estimateMinutes,
        'priority': priority,
        'mode': mode.name,
        'completedAt': completedAt?.toUtc().toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> j) {
    final pr = _toInt(j['priority'], fallback: 3);
    final clampedPriority = pr < 1
        ? 1
        : (pr > 5 ? 5 : pr); // avoid int->num cast from clamp()

    return Task(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      desc: j['desc']?.toString(),
      createdAt: _parseDate(j['createdAt']) ?? DateTime.now().toUtc(),
      completed: _toBool(j['completed'], fallback: false),
      dueAt: _parseDate(j['dueAt']),
      important: _toBool(j['important'], fallback: false),
      estimateMinutes: _toInt(j['estimateMinutes'], fallback: 0).clamp(0, 1000000),
      priority: clampedPriority,
      mode: _parseMode(j['mode']),
      completedAt: _parseDate(j['completedAt']),
    );
  }

  // ---------- Utilities ----------

  Task copyWith({
    String? id,
    String? title,
    String? desc,
    DateTime? dueAt,
    bool? important,
    int? estimateMinutes,
    int? priority,
    TaskMode? mode,
    bool? completed,
    DateTime? completedAt,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        desc: desc ?? this.desc,
        dueAt: dueAt ?? this.dueAt,
        important: important ?? this.important,
        estimateMinutes: estimateMinutes ?? this.estimateMinutes,
        priority: priority ?? this.priority,
        mode: mode ?? this.mode,
        completed: completed ?? this.completed,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt, // keep original (UTC)
      );

  @override
  String toString() =>
      'Task($id, $title, due=$dueAt, imp=$important, pri=$priority, completed=$completed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// -------- Helpers --------

TaskMode _parseMode(dynamic v) {
  if (v is String) {
    return TaskMode.values.firstWhere(
      (m) => m.name == v,
      orElse: () => TaskMode.personal,
    );
  }
  return TaskMode.personal;
}

bool isOverdue(Task t, DateTime now) {
  final due = t.dueAt;
  if (due == null) return false;
  // Compare using UTC to avoid timezone drift
  return due.toUtc().isBefore(now.toUtc()) && !t.completed;
}

bool isDueSoon(Task t, DateTime now, Duration horizon) {
  final due = t.dueAt;
  if (due == null) return false;
  final diff = due.toUtc().difference(now.toUtc());
  return diff >= Duration.zero && diff <= horizon;
}

Eisenhower classify(
  Task t,
  DateTime now, {
  Duration soon = const Duration(hours: 24),
}) {
  final urgent = isOverdue(t, now) || isDueSoon(t, now, soon);
  if (t.important && urgent) return Eisenhower.q1UrgentImportant;
  if (t.important && !urgent) return Eisenhower.q2Important;
  if (!t.important && urgent) return Eisenhower.q3Urgent;
  return Eisenhower.q4Other;
}

/// Sort inside a group:
/// 1) Overdue first
/// 2) Due date ascending (nulls last)
/// 3) Priority (1..N)  [lower number = higher priority]
/// 4) Shorter estimate first
/// 5) Older created first
int compareWithinGroup(Task a, Task b, DateTime now) {
  final ao = isOverdue(a, now) ? 0 : 1;
  final bo = isOverdue(b, now) ? 0 : 1;
  if (ao != bo) return ao - bo;

  final ad = a.dueAt;
  final bd = b.dueAt;
  if (ad != null && bd != null) {
    final d = ad.compareTo(bd);
    if (d != 0) return d;
  } else if (ad != null || bd != null) {
    return ad == null ? 1 : -1; // nulls last
  }

  final p = a.priority.compareTo(b.priority);
  if (p != 0) return p;

  final est = a.estimateMinutes.compareTo(b.estimateMinutes);
  if (est != 0) return est;

  return a.createdAt.compareTo(b.createdAt);
}

String fmt(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  final d = dt.toLocal();
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

// ----- JSON coercion helpers (robust to Firestore/loose JSON) -----

int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

bool _toBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return fallback;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  final dt = DateTime.tryParse(v.toString());
  return dt?.toUtc();
}
