import 'dart:math';
import 'package:get/get.dart';
import 'package:v3/api/dioclient.dart';
import 'package:v3/storage/authStorage.dart';

class WellbeingEventService {
  final DioClient _dio = Get.find<DioClient>();

  String _id() {
    final r = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> send({
    required String type,
    required Map<String, dynamic> context,
  }) async {
    final userId = await AuthStorage.readUserId(); // ✅ 你要有这个
    if (userId == null || userId.isEmpty) return;

    try {
      await _dio.dio.post('/wellbeing/events', data: {
        "event_id": _id(),
        "user_id": userId,
        "type": type,
        "ts": DateTime.now().toUtc().toIso8601String(),
        "context": context,
      });
    } catch (_) {
      // 不要影响主流程
    }
  }
}
