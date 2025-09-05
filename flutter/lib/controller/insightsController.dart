// lib/controller/insightsController.dart
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../api/dioclient.dart';
import '../controller/taskController.dart';
import '../storage/authStorage.dart';

class InsightsController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();
  final TaskController _tc = Get.find<TaskController>();

  final loading = false.obs;
  final summary = ''.obs;
  Map<String, dynamic>? metrics;

  Future<void> refreshInsights() async {
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
          // 如果你有记录完成时间可以加上：
          // 'completedAt': ...
        };
      }).toList();

      final res = await _dio.dio.post(
        '/ai/summary',
        data: {'user_id': userId, 'tasks': tasksPayload},
      );

      final data = res.data['data'] ?? {};
      summary.value = data['summary'] ?? '';
      metrics = Map<String, dynamic>.from(data['metrics'] ?? {});
    } on DioException catch (e) {
      summary.value = '获取分析失败：${e.message}';
    } catch (e) {
      summary.value = '发生错误：$e';
    } finally {
      loading.value = false;
    }
  }
}
