import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/walletController.dart';

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // 💉 查找钱包控制器
    // 如果你确定 WalletController 已经在 main 或者 binding 里 put 过了，直接 find
    // 如果不确定，可以用 Get.put(WalletController()) 安全一点
    final WalletController wallet = Get.find<WalletController>();

    return Center(
      child: Obx(() => Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4CC), // 淡金色背景
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: InkWell(
          onTap: () {
            // 这里以后可以写：跳转到商店
            // Get.to(() => ShopScreen());
            print("点击了金币，当前余额: ${wallet.coins.value}");
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text(
                "${wallet.coins.value}", 
                style: const TextStyle(
                  color: Colors.brown,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}