import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/apimodel.dart';
import '../api/dioclient.dart';

class TodoController extends ChangeNotifier {
  final DioClient client;
  TodoController(this.client);

  static const _kStore = 'todos_json_v1';

  List<TaskDto> tasks = [];

  // ===== Focus timer state =====
  String? focusedTaskId;
  int focusRemainingSec = 0;
  bool focusRunning = false;
  Timer? _focusTimer;

  // ===== Load / Save local =====
  Future<void> loadLocal() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kStore);
    if (raw != null && raw.isNotEmpty) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      tasks = list.map(TaskDto.fromJson).toList();
      _sort();
    }
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await sp.setString(_kStore, raw);
  }

  // ===== CRUD =====
  Future<void> fetch() async {
    await loadLocal(); // local-first
    // (Optional) also fetch remote & merge later when backend ready
  }

  Future<void> add({
    required String title,
    int priority = 3,
    int importance = 3,
    String mode = 'study',
    int? estimateMins,
    DateTime? due,
    String? notes,
  }) async {
    if (title.trim().isEmpty) return;
    final dto = TaskDto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      priority: priority,
      importance: importance,
      mode: mode,
      estimateMins: estimateMins,
      due: due,
      notes: notes,
    );
    tasks = [dto, ...tasks];
    _sort();
    await _saveLocal();
    notifyListeners();
  }

  Future<void> edit(String id, TaskDto updated) async {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    tasks[i] = updated;
    _sort();
    await _saveLocal();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    tasks.removeWhere((t) => t.id == id);
    await _saveLocal();
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final t = tasks[i];
    tasks[i] = t.copyWith(completed: !t.completed);
    _sort();
    await _saveLocal();
    notifyListeners();
  }

  // ===== Sorting (importance first, then priority, then due soonest) =====
  void _sort() {
    tasks.sort((a, b) {
      final scoreA = a.importance * 10 + a.priority; // weight importance more
      final scoreB = b.importance * 10 + b.priority;
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) return byScore;
      if (a.due != null && b.due != null) {
        return a.due!.compareTo(b.due!);
      }
      if (a.due != null) return -1;
      if (b.due != null) return 1;
      return 0;
    });
  }

  // ===== Focus Timer (tap middle) =====
  void startFocus(String taskId, {int minutes = 25}) {
    _focusTimer?.cancel();
    focusedTaskId = taskId;
    focusRemainingSec = minutes * 60;
    focusRunning = true;
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (focusRemainingSec <= 1) {
        t.cancel();
        focusRunning = false;
        focusRemainingSec = 0;
        // Auto complete? Optional:
        // toggle(taskId);
      } else {
        focusRemainingSec -= 1;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void pauseFocus() {
    if (!focusRunning) return;
    focusRunning = false;
    _focusTimer?.cancel();
    notifyListeners();
  }

  void resumeFocus() {
    if (focusRunning || focusedTaskId == null || focusRemainingSec <= 0) return;
    startFocus(focusedTaskId!, minutes: (focusRemainingSec / 60).ceil());
  }

  void stopFocus() {
    _focusTimer?.cancel();
    focusRunning = false;
    focusRemainingSec = 0;
    focusedTaskId = null;
    notifyListeners();
  }
}
