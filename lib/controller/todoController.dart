import 'package:flutter/foundation.dart';
import '../api/dioclient.dart';
import '../api/apimodel.dart';

class TodoController extends ChangeNotifier {
  final DioClient client;
  List<Map<String, dynamic>> tasks = [];
  int dailyCap = 7;

  TodoController(this.client);

  Future<ApiResponse> fetch() async {
    try {
      final res = await client.dio.get('/todos');
      final list = (res.data is List) ? List<Map<String, dynamic>>.from(res.data) : <Map<String, dynamic>>[];
      tasks = list;
      notifyListeners();
      return ApiResponse(status: 'ok', message: 'fetched', data: list);
    } catch (e) {
      return ApiResponse(status: 'error', message: e.toString());
    }
  }

  Future<ApiResponse> add(String title,
      {int? priority, int? estimateMins, DateTime? due}) async {
    if (title.trim().isEmpty) {
      return ApiResponse(status: 'error', message: 'Empty title');
    }
    if (tasks.length >= dailyCap) {
      return ApiResponse(status: 'error', message: 'Daily cap reached');
    }

    final dto = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title.trim(),
      'completed': false,
      'priority': priority,
      'estimateMins': estimateMins,
      'due': due?.toIso8601String(),
    };

    try {
      final res = await client.dio.post('/todos', data: dto);
      final saved = (res.data is Map) ? Map<String, dynamic>.from(res.data) : dto;
      tasks = [saved, ...tasks];
      notifyListeners();
      return ApiResponse(status: 'ok', message: 'added', data: saved);
    } catch (e) {
      return ApiResponse(status: 'error', message: e.toString());
    }
  }

  Future<ApiResponse> toggle(String id) async {
    final i = tasks.indexWhere((t) => t['id'] == id);
    if (i == -1) return ApiResponse(status: 'error', message: 'Not found');

    final t = tasks[i];
    final updated = {...t, 'completed': !(t['completed'] == true)};

    // optimistic UI
    tasks[i] = updated;
    notifyListeners();

    try {
      final res = await client.dio.post('/todos/$id', data: updated); // or PATCH/PUT
      final server = (res.data is Map) ? Map<String, dynamic>.from(res.data) : updated;
      tasks[i] = server;
      notifyListeners();
      return ApiResponse(status: 'ok', message: 'toggled', data: server);
    } catch (e) {
      // rollback on error
      tasks[i] = t;
      notifyListeners();
      return ApiResponse(status: 'error', message: e.toString());
    }
  }
}
