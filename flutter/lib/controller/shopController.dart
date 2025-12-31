// lib/controller/shop_controller.dart
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../api/dioclient.dart';
import '../controller/walletController.dart';
import '../models/shop_item.dart';
import '../controller/petMoodController.dart'; 

class ShopController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();
  final WalletController wallet = Get.find<WalletController>();

  final items = <ShopItem>[...ShopCatalog.items].obs;

  final foodsOwned = <String, int>{}.obs;
  final decorsOwned = <String, bool>{}.obs;
  final activeDecor = RxnString();

  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    await loadInventory();
    await wallet.fetchBalance();
  }

  void _applyInventory(Map<String, dynamic> inv) {
    final foodsRaw = Map<String, dynamic>.from(inv['foods'] ?? {});
    final decorsRaw = Map<String, dynamic>.from(inv['decors'] ?? {});

    // ✅ 关键：用 assignAll 更“GetX 友好”
    foodsOwned.assignAll(foodsRaw.map((k, v) => MapEntry(k, (v as num).toInt())));
    decorsOwned.assignAll(decorsRaw.map((k, v) => MapEntry(k, v == true)));

    activeDecor.value = inv['active_decor']?.toString();
  }

  Future<void> loadInventory() async {
    final res = await _dio.dio.get('/shop/inventory');
    final root = (res.data is Map) ? Map<String, dynamic>.from(res.data) : {};
    final data = (root['data'] is Map) ? Map<String, dynamic>.from(root['data']) : {};
    _applyInventory(data);
  }

  int qty(ShopItem it) => foodsOwned[it.id] ?? 0;
  bool isOwnedDecor(ShopItem it) => decorsOwned[it.id] ?? false;
  bool isActiveDecor(ShopItem it) => activeDecor.value == it.id;

  Future<void> purchase(ShopItem it) async {
    if (loading.value) return;
    loading.value = true;
    try {
      final res = await _dio.dio.post(
        '/shop/purchase',
        data: {
          'item_id': it.id,
          'item_type': it.category == ShopCategory.food ? 'food' : 'decor',
          'price': it.price,
          'name': it.name,
        },
      );

      final root = (res.data is Map) ? Map<String, dynamic>.from(res.data) : {};
      final data = (root['data'] is Map) ? Map<String, dynamic>.from(root['data']) : {};

      if (data['coins'] != null) {
        wallet.setCoins((data['coins'] as num).toInt());
      }
      if (data['inventory'] is Map) {
        _applyInventory(Map<String, dynamic>.from(data['inventory']));
      }

      // ✅ 宠物心情：你后端已经更新了，这里只要拉历史即可（不额外 set）
      if (Get.isRegistered<PetMoodController>()) {
        await Get.find<PetMoodController>().fetchHistory();
      }

      Get.snackbar("Purchased ✅", "You bought ${it.name}!");
    } on DioException catch (e) {
      Get.snackbar("Purchase failed ❌", "${e.response?.data ?? e.message}");
    } finally {
      loading.value = false;
    }
  }

  Future<void> useFood(ShopItem it) async {
    if (loading.value) return;
    loading.value = true;
    try {
      final res = await _dio.dio.post(
        '/shop/use-food',
        data: {'item_id': it.id},
      );

      final root = (res.data is Map) ? Map<String, dynamic>.from(res.data) : {};
      final data = (root['data'] is Map) ? Map<String, dynamic>.from(root['data']) : {};
      if (data['inventory'] is Map) {
        _applyInventory(Map<String, dynamic>.from(data['inventory']));
      }

      if (Get.isRegistered<PetMoodController>()) {
        await Get.find<PetMoodController>().fetchHistory();
      }

      Get.snackbar("Yum! 🍽️", "${it.name} used.");
    } on DioException catch (e) {
      Get.snackbar("Use failed ❌", "${e.response?.data ?? e.message}");
    } finally {
      loading.value = false;
    }
  }

  Future<void> equipDecor(ShopItem it) async {
    if (loading.value) return;
    loading.value = true;
    try {
      final res = await _dio.dio.post(
        '/shop/equip-decor',
        data: {'item_id': it.id},
      );

      final root = (res.data is Map) ? Map<String, dynamic>.from(res.data) : {};
      final data = (root['data'] is Map) ? Map<String, dynamic>.from(root['data']) : {};
      if (data['inventory'] is Map) {
        _applyInventory(Map<String, dynamic>.from(data['inventory']));
      }

      if (Get.isRegistered<PetMoodController>()) {
        await Get.find<PetMoodController>().fetchHistory();
      }

      Get.snackbar("Equipped ✨", "${it.name} equipped!");
    } on DioException catch (e) {
      Get.snackbar("Equip failed ❌", "${e.response?.data ?? e.message}");
    } finally {
      loading.value = false;
    }
  }
}
