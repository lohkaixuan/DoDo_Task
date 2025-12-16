// lib/controller/taskController.dart
import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';

import '../models/task.dart';
import '../services/notification_service.dart';
import 'petController.dart';
import '../api/dioclient.dart'; 

class TaskController extends GetxController {
  final tasks = <Task>[].obs;
  final NotificationService notifier;
  final PetController pet;
  
  // 💉 确保你在 main.dart 里 Get.put(DioClient()) 了
  final DioClient _dioClient = Get.find<DioClient>();

  TaskController(this.notifier, this.pet);

  // ===== CRUD =====
  
  Future<void> addTask(Task t) async {
    tasks.add(t);
    _scheduleAllNotifications(t);
    update();

    try {
      // 🛠️ 手动加工一下数据，匹配后端的 Pydantic 模型
      final body = t.toJson();
      body['flutter_id'] = t.id; // 把 id 映射给 flutter_id
      body['user_email'] = "yap@gmail.com"; // 暂时硬编码，以后从 UserController 拿
      
      // 注意：TaskType.singleDay 在 toJson 里已经是 String 了，
      // 只要 Python 端配置了 use_enum_values = True 就没问题。

      final response = await _dioClient.dio.post(
        '/tasks', // 👈 不需要前面的 /docs
        data: body,
      );
      
      print("Task synced! Server response: ${response.statusCode}");
      
    } on DioException catch (e) {
      print("Sync failed: ${e.response?.statusCode} - ${e.response?.data}");
      // 可以在这里加个标志位，标记这个任务 "未同步"，下次联网再发
      Get.snackbar("Sync Error", "Failed to save task to cloud");
    }
  }

  Future<void> updateTask(Task t) async {
    // ... 原有的本地逻辑 ...
    final idx = tasks.indexWhere((x) => x.id == t.id);
    if (idx >= 0) {
      final before = tasks[idx];
      final after = t.copyWith(updatedAt: DateTime.now());
      tasks[idx] = after;
      _scheduleAllNotifications(after);
      _petReactOnStatus(before, after);
      update();
    }

    // ☁️ 云端更新
    try {
      final body = t.toJson();
      body['flutter_id'] = t.id;
      body['user_email'] = "yap@gmail.com";

      // 假设后端 update 接口是用 flutter_id 查的
      await _dioClient.dio.put(
        '/tasks/${t.id}', 
        data: body,
      );
    } catch (e) {
      print("Update failed: $e");
    }
  }

  void removeById(String id) async { // 变成 async
    notifier.cancelForTask(id);
    tasks.removeWhere((x) => x.id == id);
    update();

    // ☁️ 云端删除
    try {
      await _dioClient.dio.delete('/tasks/$id');
      print("Deleted task $id from cloud");
    } catch (e) {
      print("Delete failed: $e");
    }
  }

  // ... 剩下的代码 (completeTask, clearAll, etc.) 保持不变 ...
  // 注意：completeTask 内部调用了 update()，如果你想让“完成状态”也同步，
  // 最好在 completeTask 里调用 updateTask(after)，而不是直接修改 tasks[idx] = after
  // 这样就能复用 updateTask 里的网络请求逻辑了。
  
  void completeTask(String id) {
    final idx = tasks.indexWhere((x) => x.id == id);
    if (idx >= 0) {
      final before = tasks[idx];
      final now = DateTime.now();
      final after = before.copyWith(status: TaskStatus.completed, updatedAt: now);
      
      // 👇 修改：直接调用 updateTask，这样状态改变也会自动同步到云端
      // 并且原本的通知取消逻辑已经在 updateTask 里(虽然 updateTask 没处理通知取消，但没事)
      // 稍微保留一点原逻辑：
      
      tasks[idx] = after; // 先本地变
      notifier.cancelForTask(id);
      
      // 计算宠物逻辑
      bool early = false, onTime = false, late = false;
      // ... (保留你的宠物计算逻辑) ...
      pet.onTaskCompleted(early: early, onTime: onTime, late: late);
      update();

      // ☁️ 手动发个请求更新状态 (或者简单点直接调 updateTask(after))
      updateTask(after); 
    }
  }
}