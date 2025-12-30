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

  final items = <ShopItem>[].obs;

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
    loadAll();
  }

  Future<void> loadAll() async {
    await loadItems();
    await loadInventoryToken();
    await wallet.fetchBalance();
  }

  // If you don't have /shop/items in backend, keep your local items list.
  Future<void> loadItems() async {
    // Example: keep local list (recommended if no backend items endpoint)
    // items.assignAll(ShopItem.seed());

    // OR if you have backend endpoint:
    // final res = await _dio.dio.get('/shop/items');
    // final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
    // items.assignAll(list.map(ShopItem.fromJson));
  }

  Future<void> loadInventoryToken() async {
    final res = await _dio.dio.get('/shop/inventory', options: await _authOpt());
    final data = (res.data['data'] as Map).cast<String, dynamic>();
    final inv = (data['inventory'] as Map?)?.cast<String, dynamic>() ?? {};

    foodsOwned.value = Map<String, int>.from(inv['foods'] ?? {});
    decorsOwned.value = Map<String, bool>.from(inv['decors'] ?? {});
    activeDecor.value = inv['active_decor']?.toString();
  }

  void _applyInventoryFromResp(Map<String, dynamic> data) {
    final inv = (data['inventory'] as Map?)?.cast<String, dynamic>();
    if (inv == null) return;

    foodsOwned.value = Map<String, int>.from(inv['foods'] ?? {});
    decorsOwned.value = Map<String, bool>.from(inv['decors'] ?? {});
    activeDecor.value = inv['active_decor']?.toString();
  }

  int qty(ShopItem it) => foodsOwned[it.id] ?? 0;
  bool isOwnedDecor(ShopItem it) => (decorsOwned[it.id] ?? false);
  bool isActiveDecor(ShopItem it) => activeDecor.value == it.id;

  Future<void> purchase(ShopItem it) async {
    if (loading.value) return;
    loading.value = true;

    try {
      final res = await _dio.dio.post(
        '/shop/purchase',
        data: {
          'item_id': it.id,
          'item_type': it.category.name, // food/decor
          'price': it.price,
          'name': it.name,
        },
        options: await _authOpt(),
      );

      final data = (res.data['data'] as Map).cast<String, dynamic>();

      if (data['coins'] != null) {
        wallet.setCoins((data['coins'] as num).toInt());
      }

      _applyInventoryFromResp(data); // ✅ instant UI update

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

      final data = (res.data['data'] as Map).cast<String, dynamic>();
      _applyInventoryFromResp(data); // ✅ instant UI update

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

      final data = (res.data['data'] as Map).cast<String, dynamic>();
      _applyInventoryFromResp(data); // ✅ instant UI update

      Get.snackbar("Equipped ✨", "${it.name} equipped!");
    } on DioException catch (e) {
      Get.snackbar("Equip failed ❌", "${e.response?.data ?? e.message}");
    } finally {
      loading.value = false;
    }
  }

  Future<void> refreshAll() async => loadAll();
}
