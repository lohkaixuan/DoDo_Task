// lib/controller/shopController.dart
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../api/dioclient.dart';
import '../storage/authStorage.dart';
import '../controller/walletController.dart';
import '../models/shop_item.dart';

class ShopController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();
  final WalletController wallet = Get.find<WalletController>();

  final items = <ShopItem>[...ShopCatalog.items].obs;

  final foodsOwned = <String, int>{}.obs;
  final decorsOwned = <String, bool>{}.obs;
  final activeDecor = RxnString();

  final loading = false.obs;

  Future<Options> _authOpt() async {
    final token = await AuthStorage.readToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

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
    foodsOwned.value = Map<String, int>.from(inv['foods'] ?? {});
    decorsOwned.value = Map<String, bool>.from(inv['decors'] ?? {});
    activeDecor.value = inv['active_decor']?.toString();
    foodsOwned.refresh();
    decorsOwned.refresh();
  }

  Future<void> loadInventory() async {
    final res = await _dio.dio.get(
      '/shop/inventory', // ✅ token route
      options: await _authOpt(),
    );
    final data = (res.data is Map) ? (res.data['data'] as Map? ?? {}) : <String, dynamic>{};
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
        options: await _authOpt(),
      );

      final data = (res.data is Map) ? (res.data['data'] as Map? ?? {}) : <String, dynamic>{};
      if (data['coins'] != null) wallet.setCoins((data['coins'] as num).toInt());
      if (data['inventory'] is Map) _applyInventory(Map<String, dynamic>.from(data['inventory']));

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
        options: await _authOpt(),
      );

      final data = (res.data is Map) ? (res.data['data'] as Map? ?? {}) : <String, dynamic>{};
      if (data['inventory'] is Map) _applyInventory(Map<String, dynamic>.from(data['inventory']));

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
        options: await _authOpt(),
      );

      final data = (res.data is Map) ? (res.data['data'] as Map? ?? {}) : <String, dynamic>{};
      if (data['inventory'] is Map) _applyInventory(Map<String, dynamic>.from(data['inventory']));

      Get.snackbar("Equipped ✨", "${it.name} equipped!");
    } on DioException catch (e) {
      Get.snackbar("Equip failed ❌", "${e.response?.data ?? e.message}");
    } finally {
      loading.value = false;
    }
  }
}
