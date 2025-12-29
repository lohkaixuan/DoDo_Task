// lib/controller/shopController.dart
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;

import 'package:v3/api/dioclient.dart';
import 'package:v3/controller/walletController.dart';
import 'package:v3/storage/authStorage.dart';

class ShopItem {
  final String itemId;
  final String name;
  final String type; // food / decor
  final int price;
  final int hunger; // food effect (0 for decor)

  ShopItem({
    required this.itemId,
    required this.name,
    required this.type,
    required this.price,
    required this.hunger,
  });

  factory ShopItem.fromJson(Map<String, dynamic> j) {
    return ShopItem(
      itemId: (j['item_id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      price: (j['price'] ?? 0 as num).toInt(),
      hunger: (j['hunger'] ?? 0 as num).toInt(),
    );
  }
}

class ShopController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();
  final WalletController walletC = Get.find<WalletController>();

  final items = <ShopItem>[].obs;
  final inventoryFood = <Map<String, dynamic>>[].obs;
  final inventoryDecor = <Map<String, dynamic>>[].obs;

  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // ✅ load shop & inventory
    Future.microtask(() async {
      await fetchShop();
      await fetchInventory();
    });
  }

  Future<String?> _token() async {
    final t = await AuthStorage.readToken();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<String> _userId() async {
    final uid = await AuthStorage.readUserId();
    return (uid == null || uid.trim().isEmpty)
        ? 'guest'
        : uid.trim();
  }

  Future<void> fetchShop() async {
    try {
      loading.value = true;
      final res = await _dio.dio.get('/shop/items');
      final data = res.data;

      if (data is Map && data['data'] is List) {
        final list = (data['data'] as List)
            .map((e) => ShopItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        items.assignAll(list);
      } else if (data is List) {
        // just in case backend returns raw list
        final list = data
            .map((e) => ShopItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        items.assignAll(list);
      }
    } catch (_) {
      Get.snackbar("Shop 🦈", "Failed to load shop items.");
    } finally {
      loading.value = false;
    }
  }

  Future<void> fetchInventory() async {
    final token = await _token();
    if (token == null) return;

    try {
      final uid = await _userId();
      final res = await _dio.dio.get(
        '/shop/inventory/$uid',
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (res.data is Map && res.data['data'] is Map) {
        final m = Map<String, dynamic>.from(res.data['data'] as Map);
        inventoryFood.assignAll(
          (m['food'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        inventoryDecor.assignAll(
          (m['decor'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (_) {
      // silent
    }
  }

  Future<void> purchase(ShopItem item) async {
    final token = await _token();
    if (token == null) {
      Get.snackbar("Login required 🦈", "Please login to buy items.");
      return;
    }

    try {
      loading.value = true;
      final uid = await _userId();

      final res = await _dio.dio.post(
        '/shop/purchase',
        data: {'user_id': uid, 'item_id': item.itemId},
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // expected Envelope: {status,message,data:{coins, item}}
      if (res.statusCode == 200) {
        Get.snackbar("Bought 🎉", "You purchased ${item.name}!");
        // ✅ refresh coins + inventory
        await walletC.fetchBalance();
        await fetchInventory();
      }
    } catch (_) {
      Get.snackbar("Oops 🦈", "Purchase failed. Check coins or server.");
    } finally {
      loading.value = false;
    }
  }
}
