// ==================================================
// Program Name   : moodController.dart
// Purpose        : Manage user mood logging and wellbeing history, including submission, validation, and reactive UI updates.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 02 October 2025
// Last Modified  : 13 December 2025
// ==================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../api/dioclient.dart';
import '../storage/authStorage.dart';
import '../models/mood_log.dart';

class MoodController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();

  final selected = "neutral".obs;
  final notes = "".obs;
  final loading = false.obs;

  final history = <MoodLog>[].obs;
  final loadingHistory = false.obs;

  final notesCtrl = TextEditingController();

  Future<Options> _authOpt() async {
    final token = await AuthStorage.readToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  void onInit() {
    super.onInit();
    fetchHistory(); // ✅ auto load when page opens
  }

  @override
  void onClose() {
    notesCtrl.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    if (loading.value) return;
    loading.value = true;

    try {
      final req = MoodLogReq(
        moodId: "m_${DateTime.now().microsecondsSinceEpoch}",
        source: "user_slider",
        label: selected.value,
        confidence: 1.0,
        notes: notes.value.trim().isEmpty ? null : notes.value.trim(),
      );

      await _dio.dio.post(
        "/wellbeing/mood",
        data: req.toJson(),
        options: await _authOpt(),
      );

      await fetchHistory(); // ✅ refresh immediately

      notes.value = "";
      notesCtrl.clear();
      Get.snackbar("Saved ✅", "Mood logged!");
    } on DioException catch (e) {
      Get.snackbar("Failed ❌", "${e.response?.data ?? e.message}");
    } finally {
      loading.value = false;
    }
  }

  Future<void> fetchHistory() async {
    loadingHistory.value = true;
    try {
      final res = await _dio.dio.get(
        '/wellbeing/mood/history?limit=30',
        options: await _authOpt(),
      );

      final data = res.data;
      final list = (data is Map) ? (data['data'] as List? ?? []) : <dynamic>[];

      final parsed = list
          .map((e) => MoodLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // ✅ optional: latest first
      parsed.sort((a, b) => b.ts.compareTo(a.ts));

      history.assignAll(parsed);
    } catch (e) {
      // ✅ swallow errors so UI doesn't crash
      print("⚠️ MoodController.fetchHistory failed: $e");
      // optional UI hint
      // Get.snackbar("Network", "Unable to load mood history");
    } finally {
      loadingHistory.value = false;
    }
  }
}
