// lib/controller/insightsController.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:v3/api/dioclient.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/models/task.dart';
import 'package:v3/storage/authStorage.dart';

class InsightsController extends GetxController {
  late final DioClient _dio;
  late final TaskController _tc;

  final loading = false.obs;
  final summary = ''.obs;
  final metrics = <String, dynamic>{}.obs; // ✅ RxMap

  Worker? _tasksWorker;
  bool _booted = false;
  bool _skipFirstTasksEvent = true;

  @override
  void onInit() {
    super.onInit();

    _dio = Get.find<DioClient>();
    _tc = Get.find<TaskController>();

    // run once (avoid startup jank)
    Future.microtask(() async {
      if (_booted) return;
      _booted = true;
      await refreshInsights();
    });

    // auto refresh when tasks changed (debounced)
    _tasksWorker = debounce<List<Task>>(
      _tc.tasks,
      (_) async {
        if (_skipFirstTasksEvent) {
          _skipFirstTasksEvent = false;
          return;
        }
        await refreshInsights();
      },
      time: const Duration(milliseconds: 600),
    );
  }

  @override
  void onClose() {
    _tasksWorker?.dispose();
    super.onClose();
  }

  Future<void> refreshInsights() async {
    if (loading.value) return;
    loading.value = true;

    try {
      final userId = (await AuthStorage.readUserId()) ?? 'guest';

      final tasksPayload = _tc.tasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'category': t.category,
        'status': t.status.name,
        'type': t.type.name,
        'dueDateTime': t.dueDateTime?.toIso8601String(),
        'startDate': t.startDate?.toIso8601String(),
        'dueDate': t.dueDate?.toIso8601String(),
        'estimatedMinutes': t.estimatedMinutes,
        'spentMinutes': t.spentMinutes,
        'priority': t.priority.name,
        'important': t.important,
      }).toList();

      final res = await _dio.dio
          .post('/ai/summary', data: {'user_id': userId, 'tasks': tasksPayload})
          .timeout(const Duration(seconds: 12));

      final data = (res.data is Map) ? (res.data as Map) : {};
      final payload = (data['data'] is Map) ? (data['data'] as Map) : {};

      summary.value = (payload['summary'] ?? '').toString();

      final m = payload['metrics'];
      metrics.assignAll(m is Map ? Map<String, dynamic>.from(m) : {});
    } on TimeoutException {
      summary.value = 'Server timeout. Try again.';
      metrics.clear();
    } on DioException catch (e) {
      summary.value = 'Failed to get analysis report: ${e.message}';
      metrics.clear();
    } catch (e) {
      summary.value = 'Error: $e';
      metrics.clear();
    } finally {
      loading.value = false;
    }
  }
}
