// lib/controller/shopController.dart
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

  final inventoryLoading = true.obs;
  final inventoryReady = false.obs;


  PetMoodController? get _pet => Get.isRegistered<PetMoodController>()
      ? Get.find<PetMoodController>()
      : null;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    inventoryLoading.value = true;
    try {
      await Future.wait([
        loadInventory(),
        wallet.fetchBalance(),
        _pet?.refreshAll() ?? Future.value(),
      ]);
      inventoryReady.value = true;
    } finally {
      inventoryLoading.value = false;
    }
  }

  void _applyInventory(Map<String, dynamic> inv) {
    final foodsRaw = Map<String, dynamic>.from(inv['foods'] ?? {});
    final decorsRaw = Map<String, dynamic>.from(inv['decors'] ?? {});

    foodsOwned.assignAll(
      foodsRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
    decorsOwned.assignAll(
      decorsRaw.map((k, v) => MapEntry(k, v == true)),
    );

    activeDecor.value = inv['active_decor']?.toString();
  }

  Future<void> loadInventory() async {
    final res = await _dio.dio.get('/shop/inventory');

    final root = (res.data is Map)
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};

    final data = (root['data'] is Map)
        ? Map<String, dynamic>.from(root['data'] as Map)
        : <String, dynamic>{};

    _applyInventory(data);

    // ✅ optional: 标记 ready（如果你不想放在 refreshAll 也行）
    inventoryReady.value = true;
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
      final data =
          (root['data'] is Map) ? Map<String, dynamic>.from(root['data']) : {};

      if (data['coins'] != null) {
        wallet.setCoins((data['coins'] as num).toInt());
      }
      if (data['inventory'] is Map) {
        _applyInventory(Map<String, dynamic>.from(data['inventory']));
      }

      // ✅ backend already updated pet mood -> just refresh it
      await _pet?.refreshAll();

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
      final res =
          await _dio.dio.post('/shop/use-food', data: {'item_id': it.id});

      final root = (res.data is Map) ? Map<String, dynamic>.from(res.data) : {};
      final data =
          (root['data'] is Map) ? Map<String, dynamic>.from(root['data']) : {};
      if (data['inventory'] is Map) {
        _applyInventory(Map<String, dynamic>.from(data['inventory']));
      }

      await _pet?.refreshAll();

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
      final res =
          await _dio.dio.post('/shop/equip-decor', data: {'item_id': it.id});

      final root = (res.data is Map) ? Map<String, dynamic>.from(res.data) : {};
      final data =
          (root['data'] is Map) ? Map<String, dynamic>.from(root['data']) : {};
      if (data['inventory'] is Map) {
        _applyInventory(Map<String, dynamic>.from(data['inventory']));
      }

      await _pet?.refreshAll();

      Get.snackbar("Equipped ✨", "${it.name} equipped!");
    } on DioException catch (e) {
      Get.snackbar("Equip failed ❌", "${e.response?.data ?? e.message}");
    } finally {
      loading.value = false;
    }
  }
}
