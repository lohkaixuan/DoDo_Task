// lib/controller/walletController.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../api/dioclient.dart';
// 👇 1. 引入 AuthService (假设你把 Token 存在这里)
// 如果你的 Token 存在 GetStorage 或其他地方，请相应修改
import '../services/auth_service.dart'; 

class WalletController extends GetxController {
  final DioClient _dioClient = Get.find<DioClient>();

  // 💰 钱包余额
  final coins = 0.obs;
  final email = "".obs;

  @override
  void onInit() {
    super.onInit();
    // 注意：如果是 App 刚启动还没登录，这里可能会失败，
    // 所以建议在登录成功后也手动调用一次 fetchBalance()
    fetchBalance(); 
  }

  // 📥 1. 查余额 (GET /balance)
  Future<void> fetchBalance() async {
    try {
      // 👇 2. 获取 Token (关键步骤！)
      // 请确保你的 AuthService 里有一个叫 token 的变量或者方法
      // 如果你的写法不一样（比如 AuthService.to.token），请在这里改
      String? token;
      try {
        token = Get.find<AuthService>().token; 
      } catch (e) {
        print("⚠️ 找不到 AuthService，可能还没登录");
      }

      if (token == null || token.isEmpty) {
        print("⚠️ 没有 Token，无法查账");
        return;
      }

      // 👇 3. 发请求时带上身份证！
      final response = await _dioClient.dio.get(
        '/balance',
        options: Options(headers: {
          'Authorization': 'Bearer $token', // ✅ 这一行是能否读到 Database 的关键
        }),
      );

      if (response.statusCode == 200) {
        coins.value = response.data['coins']; // ✅ 读取 Database 里的原有金币
        if (response.data['email'] != null) {
          email.value = response.data['email'];
        }
        print("💰 钱包同步成功: Database 里有 ${coins.value} 金币");
      }
    } catch (e) {
      print("⚠️ 查账失败: $e");
    }
  }

  // 💸 2. 花钱 (POST /balance/spend)
  Future<bool> spendCoins(int amount, String itemName) async {
    if (coins.value < amount) {
      Get.snackbar("穷鬼警告 💸", "你的金币不够买 $itemName 啦！快去完成任务！");
      return false;
    }

    try {
      // 👇 花钱也要带 Token
      String? token = Get.find<AuthService>().token;
      
      final response = await _dioClient.dio.post(
        '/balance/spend',
        data: {'amount': amount, 'item_name': itemName},
        options: Options(headers: {
          'Authorization': 'Bearer $token', // ✅ 带上 Token
        }),
      );

      if (response.statusCode == 200) {
        coins.value = response.data['remaining_coins'];
        Get.snackbar("购买成功 🎁", "花费 $amount 金币购买了 $itemName");
        return true;
      }
    } catch (e) {
      print("⚠️ 支付失败: $e");
      Get.snackbar("支付失败", "服务器开小差了，没扣钱");
    }
    return false;
  }

  // ➕➖ 3. 本地更新逻辑 (保持不变)
  void addCoinsLocally(int amount) {
    coins.value += amount;
    if (amount > 0) {
      Get.snackbar(
        "Cha-Ching! 💰", 
        "Task Completed! +$amount Coins",
        backgroundColor: const Color(0xFFFFD700),
        colorText: Colors.black,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(10),
      );
    } else {
      Get.snackbar(
        "Task Unfinished ↩️", 
        "Refunded! $amount Coins",
        backgroundColor: Colors.redAccent.shade100,
        colorText: Colors.white,
        icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(10),
      );
    }
  }
}