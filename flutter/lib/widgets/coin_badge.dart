import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/walletController.dart';

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final WalletController wallet = Get.find<WalletController>();

    return Obx(() => InkWell(
          onTap: () => Get.toNamed('/shop'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4CC),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Colors.amber, size: 18),
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
        ));
  }
}
