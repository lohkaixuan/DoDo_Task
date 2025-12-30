// lib/controller/shopController.dart
import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../api/dioclient.dart';
import '../storage/authStorage.dart';
import '../controller/walletController.dart';
import '../models/shop_item.dart';

class ShopController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();
  final WalletController wallet = Get.find<WalletController>();

  final items = <ShopItem>[].obs;

  // inventory from backend
  final foodsOwned = <String, int>{}.obs;
  final decorsOwned = <String, bool>{}.obs;
  final activeDecor = RxnString();

  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    items.assignAll(ShopItem.defaults()); // local catalog
    refreshAll();
  }

  Future<String?> _userId() async {
    final uid = await AuthStorage.readUserId();
    if (uid == null || uid.trim().isEmpty) return null;
    return uid.trim();
  }

  Future<Options> _authOpt() async {
    final token = await AuthStorage.readToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  int qty(ShopItem it) => foodsOwned[it.id] ?? 0;

  bool isOwnedDecor(ShopItem it) => (decorsOwned[it.id] ?? false);

  bool isActiveDecor(ShopItem it) => activeDecor.value == it.id;
  final refreshTick = 0.obs;

  Future<void> refreshAll() async {
    await loadInventory();
    await wallet.fetchBalance();
    refreshTick.value++;   
  }

  Future<void> loadInventory() async {
    final uid = await _userId();
    if (uid == null) {
      // not logged in -> clear UI inventory
      foodsOwned.clear();
      decorsOwned.clear();
      activeDecor.value = null;
      return;
    }

    try {
      final res = await _dio.dio.get(
        '/shop/inventory/$uid',
        options: await _authOpt(), // ok even if backend doesn't use it
      );

      final data = (res.data is Map) ? (res.data['data'] as Map?) : null;
      if (data == null) return;

      foodsOwned.value = Map<String, int>.from(data['foods'] ?? {});
      decorsOwned.value = Map<String, bool>.from(data['decors'] ?? {});
      activeDecor.value = data['active_decor']?.toString();
    } catch (_) {
      // keep silent, don't crash UI
    }
  }

  Future<void> purchase(ShopItem it) async {
    if (loading.value) return;
    loading.value = true;

    try {
      final uid = await _userId();
      if (uid == null) {
        Get.snackbar("Login required 🦈", "Please login to use the shop.");
        return;
      }

      final res = await _dio.dio.post(
        '/shop/purchase',
        data: {
          "user_id": uid,
          "item_id": it.id,
          "item_type": it.itemTypeString,
          "price": it.price,
          "name": it.name,
        },
        options: await _authOpt(),
      );

      final data = (res.data is Map) ? (res.data['data'] as Map?) : null;
      if (data == null) {
        Get.snackbar("Purchase ✅", "Bought ${it.name}");
        await refreshAll();
        return;
      }

      if (data['coins'] != null) {
        wallet.setCoins((data['coins'] as num).toInt());
      }

      // backend purchase currently returns only {coins, item_id, type}
      // so we re-load inventory to update counts
      await loadInventory();

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
      final uid = await _userId();
      if (uid == null) {
        Get.snackbar("Login required 🦈", "Please login first.");
        return;
      }

      final res = await _dio.dio.post(
        '/shop/use-food',
        data: {"user_id": uid, "item_id": it.id},
        options: await _authOpt(),
      );

      // backend returns {used, item_id} so reload inventory
      await loadInventory();
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
      final uid = await _userId();
      if (uid == null) {
        Get.snackbar("Login required 🦈", "Please login first.");
        return;
      }

      final res = await _dio.dio.post(
        '/shop/equip-decor',
        data: {"user_id": uid, "item_id": it.id},
        options: await _authOpt(),
      );

      final data = (res.data is Map) ? (res.data['data'] as Map?) : null;
      final active = data?['active_decor']?.toString();
      activeDecor.value = active ?? it.id;

      Get.snackbar("Equipped ✨", "${it.name} equipped!");
    } on DioException catch (e) {
      Get.snackbar("Equip failed ❌", "${e.response?.data ?? e.message}");
    } finally {
      loading.value = false;
    }
  }
}
