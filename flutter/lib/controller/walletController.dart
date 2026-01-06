// ==================================================
// Program Name   : walletController.dart
// Purpose        : Manage user virtual wallet including coin balance retrieval, updates, and backend synchronization.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 26 August 2025
// Last Modified  : 04 December 2025
// ==================================================

import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../api/dioclient.dart';
import '../storage/authStorage.dart';

class WalletController extends GetxController {
  final DioClient _dioClient = Get.find<DioClient>();

  final coins = 0.obs;
  final email = "".obs;

  Future<void> fetchBalance() async {
    final token = await AuthStorage.readToken();
    if (token == null || token.isEmpty) {
      // not logged in, ignore
      return;
    }

    try {
      final res = await _dioClient.dio.get(
        '/balance',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (res.statusCode == 200 && res.data is Map) {
        final m = Map<String, dynamic>.from(res.data as Map);
        coins.value = ((m['coins'] ?? 0) as num).toInt();
        email.value = (m['email'] ?? '').toString();
      }
    } catch (_) {
      // silent fail, don't break UI
    }
  }

// For future use - mini game
/*
  Future<bool> spendCoins({
    required int amount,
    required String itemName,
  }) async {
    final token = await AuthStorage.readToken();
    if (token == null || token.isEmpty) {
      Get.snackbar("Login required", "Please login to use the shop.");
      return false;
    }

    if (coins.value < amount) {
      Get.snackbar("Not enough coins 💸", "You need more coins to buy $itemName");
      return false;
    }

    try {
      final res = await _dioClient.dio.post(
        '/balance/spend',
        data: {'amount': amount, 'item_name': itemName},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (res.statusCode == 200 && res.data is Map) {
        final m = Map<String, dynamic>.from(res.data as Map);
        coins.value = ((m['coins'] ?? coins.value) as num).toInt();
        return true;
      }
    } catch (_) {}

    return false;
  }*/

  void setCoins(int v) {
    coins.value = v;
  }
}
