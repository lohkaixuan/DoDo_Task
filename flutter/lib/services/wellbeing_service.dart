// ==================================================
// Program Name   : wellbeing_service.dart
// Purpose        : Provide service layer for wellbeing-related features, including mood tracking, pet wellbeing, and health productivity communication with backend.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 02 October 2025
// Last Modified  : 13 December 2025
// ==================================================

import 'dart:math';
import 'package:get/get.dart';
import 'package:v3/api/dioclient.dart';

class WellbeingEventService {
  final DioClient _dio = Get.find<DioClient>();

  String _id() {
    final r = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> send({
    required String type,
    Map<String, dynamic>? context,
    DateTime? ts,
  }) async {
    try {
      await _dio.dio.post('/wellbeing/events', data: {
        "event_id": _id(),
        "type": type,
        "ts": (ts ?? DateTime.now()).toUtc().toIso8601String(),
        "context": context ?? {},
      });
    } catch (_) {
      // do nothing: never break main flow
    }
  }
}
