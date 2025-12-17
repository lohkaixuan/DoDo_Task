// lib/controller/walletController.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../api/dioclient.dart';

class WalletController extends GetxController {
  final DioClient _dioClient = Get.find<DioClient>();

  // 💰 钱包余额 (RxInt 让 UI 自动刷新)
  final coins = 0.obs;

  // 📧 顺便存个邮箱，以后可能用得着
  final email = "".obs;

  @override
  void onInit() {
    super.onInit();
    fetchBalance(); // 🚀 一启动就查账
  }

  // 📥 1. 查余额 (GET /balance)
  Future<void> fetchBalance() async {
    try {
      final response = await _dioClient.dio.get('/balance');
      if (response.statusCode == 200) {
        coins.value = response.data['coins'];
        email.value = response.data['email'];
        print("💰 钱包同步成功: ${coins.value} coins");
      }
    } catch (e) {
      print("⚠️ 查账失败: $e");
    }
  }

  // 💸 2. 花钱 (POST /balance/spend)
  Future<bool> spendCoins(int amount, String itemName) async {
    // 🛑 先在本地拦一道，没钱别去骚扰后端
    if (coins.value < amount) {
      Get.snackbar("穷鬼警告 💸", "你的金币不够买 $itemName 啦！快去完成任务！");
      return false;
    }

    try {
      final response = await _dioClient.dio.post('/balance/spend',
          data: {'amount': amount, 'item_name': itemName});

      if (response.statusCode == 200) {
        // ✅ 后端扣款成功，更新本地余额
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

  // ➕➖ 3. 智能加减钱 (自动判断是奖励还是惩罚)
  void addCoinsLocally(int amount) {
    coins.value += amount;

    // 🟢 情况 A: 赚钱了 (Amount > 0)
    if (amount > 0) {
      Get.snackbar(
        "Cha-Ching! 💰", 
        "Task Completed! +$amount Coins",
        backgroundColor: const Color(0xFFFFD700), // 金色背景
        colorText: Colors.black,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(10),
      );
    } 
    // 🔴 情况 B: 扣钱了 (Amount < 0)
    else {
      Get.snackbar(
        "Task Unfinished ↩️", // 标题：任务未完成
        "Refunded! $amount Coins", // 内容：-10 金币
        backgroundColor: Colors.redAccent.shade100, // 红色背景，警示一下
        colorText: Colors.white,
        icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(10),
      );
    }
  }
}
