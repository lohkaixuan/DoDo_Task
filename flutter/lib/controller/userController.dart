// ==================================================
// Program Name   : userController.dart
// Purpose        : Manage authenticated user profile data including display name, email, and session-related user information.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 24 August 2025
// Last Modified  : 05 December 2025
// ==================================================

import 'package:get/get.dart';
import 'package:v3/api/dioclient.dart';

class UserController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();

  final userId = ''.obs;
  final email = ''.obs;
  final displayName = ''.obs;
  final coins = 0.obs;

  Future<void> fetchMe() async {
    try {
      final res = await _dio.dio.get('/users/me');

      final raw = res.data;
      final data = (raw is Map && raw['data'] is Map)
          ? Map<String, dynamic>.from(raw['data'])
          : (raw is Map ? Map<String, dynamic>.from(raw) : null);

      if (data == null) return;

      userId.value = (data['user_id'] ?? '').toString();
      email.value = (data['email'] ?? '').toString();
      displayName.value = (data['display_name'] ?? '').toString();

      final c = data['coins'];
      coins.value = (c is num) ? c.toInt() : int.tryParse('$c') ?? 0;
    } catch (_) {
      // silent fail
    }
  }
  
  void reset() {
    userId.value = '';
    email.value = '';
    displayName.value = '';
    coins.value = 0;
  }
}
