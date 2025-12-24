// lib/controller/insightsController.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../api/dioclient.dart';
import '../controller/taskController.dart';
import '../storage/authStorage.dart';
import '../models/task.dart';

class InsightsController extends GetxController {
  late final DioClient _dio;
  late final TaskController _tc;

  final loading = false.obs;
  final summary = ''.obs;

  // ✅ MUST be RxMap (because you use assignAll/clear + UI can react)
  final metrics = <String, dynamic>{}.obs;

  Worker? _tasksWorker;
  bool _booted = false;
  bool _skipFirstTasksEvent = true;

  @override
  void onInit() {
    super.onInit();

    // ✅ delay Get.find into onInit (safe)
    _dio = Get.find<DioClient>();
    _tc = Get.find<TaskController>();

    // ✅ 1) run once after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_booted) return;
      _booted = true;

      // If tasks not yet loaded, you can still allow refresh (will send empty list).
      await refreshInsights();
    });

    // ✅ 2) auto refresh when tasks changed (debounced)
    _tasksWorker = debounce<List<Task>>(
      _tc.tasks,
      (_) async {
        // Prevent the initial assignAll from causing an extra refresh
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
    if (loading.value) return; // ✅ avoid concurrent loop
    loading.value = true;

    try {
      final userId = (await AuthStorage.readUserId()) ?? 'guest';

      final tasksPayload = _tc.tasks.map((t) {
        return {
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
        };
      }).toList();

      // ✅ timeout so slow server won't feel like freeze
      final res = await _dio.dio
          .post(
            '/ai/summary',
            data: {'user_id': userId, 'tasks': tasksPayload},
          )
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
