// lib/controller/shopController.dart
import 'package:get/get.dart';
import 'package:v3/api/dioclient.dart';
import 'package:v3/controller/walletController.dart';
import 'package:v3/models/shop_item.dart';
import 'package:v3/storage/authStorage.dart';

class ShopController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();
  final WalletController walletC = Get.find<WalletController>();

  final items = <ShopItem>[].obs;

  // inventory
  final foodQty = <String, int>{}.obs;        // itemId -> qty
  final ownedDecors = <String>{}.obs;         // set of decor ids
  final activeDecor = RxnString();            // decor id
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    await walletC.fetchBalance();
    await fetchItems();
    await fetchInventory();
  }

  Future<String> _uid() async {
    final v = await AuthStorage.readUserId();
    return (v != null && v.trim().isNotEmpty) ? v.trim() : 'guest';
  }

  // -------------------------
  // API calls
  // -------------------------
  Future<void> fetchItems() async {
    try {
      final res = await _dio.dio.get('/shop/items');
      final data = res.data;

      // support Envelope {data:[...]} or raw list
      final list = (data is Map && data['data'] is List)
          ? (data['data'] as List)
          : (data is List ? data : const []);

      items.assignAll(
        list.map((e) => ShopItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
    } catch (_) {
      // fallback: hardcode (optional)
      items.assignAll(const [
        ShopItem(id: 'apple', name: 'Apple', category: ShopCategory.food, price: 5, asset: 'assets/shop/food/apple.png', hunger: 10),
        ShopItem(id: 'milk', name: 'Milk', category: ShopCategory.food, price: 8, asset: 'assets/shop/food/milk.png', hunger: 15),
        ShopItem(id: 'bento', name: 'Bento', category: ShopCategory.food, price: 12, asset: 'assets/shop/food/bento.png', hunger: 25),
        ShopItem(id: 'lamp', name: 'Lamp', category: ShopCategory.decor, price: 30, asset: 'assets/shop/decor/lamp.png'),
        ShopItem(id: 'plant', name: 'Plant', category: ShopCategory.decor, price: 25, asset: 'assets/shop/decor/plant.png'),
      ]);
    }
  }

  Future<void> fetchInventory() async {
    final userId = await _uid();
    try {
      final res = await _dio.dio.get('/shop/inventory/$userId');
      final data = (res.data is Map) ? res.data : {};

      final inv = (data['data'] ?? data) as Map;
      final foods = (inv['foods'] is Map) ? Map<String, dynamic>.from(inv['foods']) : <String, dynamic>{};
      final decors = (inv['decors'] is Map) ? Map<String, dynamic>.from(inv['decors']) : <String, dynamic>{};

      foodQty.assignAll(foods.map((k, v) => MapEntry(k, (v is num) ? v.toInt() : int.tryParse('$v') ?? 0)));
      ownedDecors.assignAll(decors.keys.map((e) => e.toString()));
      activeDecor.value = inv['active_decor']?.toString();
    } catch (e) {
      // keep local empty if fail
    }
  }

  int qty(ShopItem it) => foodQty[it.id] ?? 0;
  bool isOwnedDecor(String decorId) => ownedDecors.contains(decorId);
  bool isActiveDecor(String decorId) => activeDecor.value == decorId;

  // -------------------------
  // Actions
  // -------------------------
  Future<void> buyFood(ShopItem it) => _purchase(it);
  Future<void> buyDecor(ShopItem it) => _purchase(it);

  Future<void> _purchase(ShopItem it) async {
    if (loading.value) return;
    loading.value = true;

    final userId = await _uid();
    try {
      final res = await _dio.dio.post('/shop/purchase', data: {
        'user_id': userId,
        'item_id': it.id,
      });

      final data = (res.data is Map) ? res.data : {};
      final out = (data['data'] ?? data) as Map;

      // update coins
      final coins = out['coins'];
      if (coins is num) walletC.coins.value = coins.toInt();

      // refresh inventory
      await fetchInventory();

      Get.snackbar('Purchased 🦈', '${it.name} acquired!');
    } catch (e) {
      Get.snackbar('Purchase failed', e.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> useFood(ShopItem it) async {
    if (loading.value) return;
    if (qty(it) <= 0) return;

    loading.value = true;
    final userId = await _uid();

    try {
      await _dio.dio.post('/shop/use', data: {
        'user_id': userId,
        'item_id': it.id,
      });

      await fetchInventory();
      Get.snackbar('Yum 🍎', 'DoDo enjoyed ${it.name}!');
    } catch (e) {
      Get.snackbar('Use failed', e.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> equipDecor(ShopItem it) async {
    if (loading.value) return;
    if (!isOwnedDecor(it.id)) return;

    loading.value = true;
    final userId = await _uid();

    try {
      await _dio.dio.post('/shop/equip', data: {
        'user_id': userId,
        'decor_id': it.id,
      });

      await fetchInventory();
      Get.snackbar('Equipped ✨', '${it.name} is now active!');
    } catch (e) {
      Get.snackbar('Equip failed', e.toString());
    } finally {
      loading.value = false;
    }
  }
}
