import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../api/dioclient.dart';
import '../models/task.dart';
import 'petController.dart';

class TaskController extends GetxController {
  final Dio _dio;
  final PetController petC;
  TaskController(DioClient client, this.petC) : _dio = client.dio;

  final tasks = <Task>[].obs;
  final loading = false.obs;
  final active = Rxn<Task>();

  Future<void> loadByUser(String userId) async {
    loading.value = true;
    try {
      final r = await _dio.get('/tasks/by-user', queryParameters: {'user_id': userId});
      tasks.assignAll((r.data as List).map((e) => Task.fromJson(Map<String, dynamic>.from(e))));
    } catch (_) {
      tasks.clear();
    } finally {
      loading.value = false;
    }
  }

  Map<String, List<Task>> groupedByCategory() {
    final map = <String, List<Task>>{};
    for (final t in tasks) {
      map.putIfAbsent(t.category, () => []);
      map[t.category]!.add(t);
    }
    return map;
  }

  double completionFor(String category) {
    final group = tasks.where((t) => t.category == category).toList();
    if (group.isEmpty) return 0;
    final done = group.where((t) => t.status == TaskStatus.done).length;
    return done / group.length;
  }

  Future<void> startFocus(Task t, String userId) async {
    active.value = t;
    petC.setAction('focus');
    await _dio.post('/tasks/${t.id}/start', queryParameters: {'user_id': userId});
  }

  Future<void> completeActive(String userId) async {
    final t = active.value;
    if (t == null) return;
    await _dio.patch('/tasks/${t.id}/complete', queryParameters: {'user_id': userId});
    petC.setAction('celebrate');
    active.value = null;
  }

  void stopFocus() {
    petC.setAction('idle');
    active.value = null;
  }
}
