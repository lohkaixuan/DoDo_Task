import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../api/dioclient.dart';
import '../models/pet_risk.dart';


class PetController extends GetxController {
  final Dio _dio;
  PetController(DioClient client) : _dio = client.dio;

  final risk = Rxn<PetRisk>();   // <-- Rxn so you can use .value in Obx
  final loading = false.obs;
  final currentAction = 'idle'.obs; // 'idle' | 'focus' | 'celebrate' | ...

  Future<void> fetchRisk(String userId) async {
    loading.value = true;
    try {
      final r = await _dio.get('/wellbeing/risk/$userId');
      risk.value = PetRisk.fromJson(Map<String, dynamic>.from(r.data));
    } finally {
      loading.value = false;
    }
  }

  void setAction(String action) => currentAction.value = action;
}
