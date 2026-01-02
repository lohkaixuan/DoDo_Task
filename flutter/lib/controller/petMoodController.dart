// lib/controller/petMoodController.dart
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:v3/storage/authStorage.dart';
import '../api/dioclient.dart';

class PetMoodLog {
  final String mood;
  final String reason;
  final DateTime ts;

  PetMoodLog({required this.mood, required this.reason, required this.ts});

  factory PetMoodLog.fromJson(Map<String, dynamic> j) {
    return PetMoodLog(
      mood: (j['mood'] ?? 'idle').toString(),
      reason: (j['reason'] ?? '').toString(),
      ts: DateTime.tryParse((j['ts'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class PetMoodController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();

  final currentMood = 'idle'.obs;
  final logs = <PetMoodLog>[].obs;
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    final token = await AuthStorage.readToken();
    if (token == null || token.isEmpty) {
      print('🧊 [PetMood] skip refreshAll: no token');
      return;
    }
    await Future.wait([fetchPetState(), fetchHistory()]);
  }

  Future<void> fetchPetState() async {
    try {
      final res = await _dio.dio.get('/wellbeing/pet');
      final root = Map<String, dynamic>.from(res.data as Map);
      final data = Map<String, dynamic>.from(root['data'] as Map? ?? {});
      currentMood.value = (data['mood'] ?? 'idle').toString();
    } catch (_) {
      // keep old mood, don't crash UI
    }
  }

  Future<void> fetchHistory() async {
    try {
      final res = await _dio.dio.get('/wellbeing/pet/mood/history?limit=30');
      final root = Map<String, dynamic>.from(res.data as Map);
      final list = (root['data'] as List? ?? []).cast<dynamic>();

      final parsed = list
          .map((e) => PetMoodLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // ✅ ensure latest-first
      parsed.sort((a, b) => b.ts.compareTo(a.ts));

      logs.assignAll(parsed);

      if (parsed.isNotEmpty) {
        currentMood.value = parsed.first.mood; // ✅ latest now
      }
    } catch (_) {}
  }

  /// Optional manual override (keep it, useful for admin/debug)
  Future<void> setMood(String mood, {required String reason}) async {
    if (loading.value) return;
    loading.value = true;
    try {
      await _dio.dio.post('/wellbeing/pet/mood', data: {
        'mood': mood,
        'reason': reason,
      });
      await refreshAll();
    } finally {
      loading.value = false;
    }
  }

  void reset() {
    currentMood.value = 'idle';
    logs.clear();
  }
}
