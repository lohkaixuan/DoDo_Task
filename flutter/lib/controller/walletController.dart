// lib/controller/walletController.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../api/dioclient.dart';
import '../storage/authStorage.dart'; // ✅ use AuthStorage (FlutterSecureStorage)

class WalletController extends GetxController {
  final DioClient _dioClient = Get.find<DioClient>();

  final coins = 0.obs;
  final email = "".obs;

  @override
  void onInit() {
    super.onInit();
    // ok to call; if no token yet it will just skip
    fetchBalance();
  }

  // 📥 GET /balance
  Future<void> fetchBalance() async {
    try {
      final token = await AuthStorage.readToken(); // ✅
      if (token == null || token.isEmpty) {
        print("⚠️ [Wallet] No token yet, skip fetchBalance");
        return;
      }

      final response = await _dioClient.dio.get(
        '/balance',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print("✅ [Wallet] /balance status=${response.statusCode} data=${response.data}");

      if (response.statusCode == 200) {
        coins.value = (response.data['coins'] ?? 0) as int;
        email.value = (response.data['email'] ?? "") as String;
      }
    } catch (e) {
      print("❌ [Wallet] fetchBalance failed: $e");
    }
  }

  // 💸 POST /balance/spend
  Future<bool> spendCoins(int amount, String itemName) async {
    if (coins.value < amount) {
      Get.snackbar("Not enough coins 💸", "You need more coins to buy $itemName");
      return false;
    }

    try {
      final token = await AuthStorage.readToken(); // ✅
      if (token == null || token.isEmpty) {
        Get.snackbar("Auth missing", "Please login again.");
        return false;
      }

      final response = await _dioClient.dio.post(
        '/balance/spend',
        data: {'amount': amount, 'item_name': itemName},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print("✅ [Wallet] /balance/spend status=${response.statusCode} data=${response.data}");

      if (response.statusCode == 200) {
        coins.value = (response.data['coins'] ?? coins.value) as int;
        return true;
      }
    } catch (e) {
      print("❌ [Wallet] spendCoins failed: $e");
    }
    return false;
  }

  // local UI update (optional)
  void addCoinsLocally(int amount) {
    coins.value += amount;
  }
}
