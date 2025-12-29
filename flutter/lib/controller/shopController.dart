// lib/controller/shopController.dart
import 'package:get/get.dart';
import 'package:v3/api/dioclient.dart';
import 'package:v3/controller/walletController.dart';
import 'package:v3/models/shop_item.dart';
import 'package:v3/storage/authStorage.dart';

class ShopController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();
  final WalletController walletC = Get.find<WalletController>();

  final loading = false.obs;

  // Inventory from backend
  final foodsQty = <String, int>{}.obs;       // itemId -> qty
  final decorsOwned = <String, bool>{}.obs;   // itemId -> owned
  final activeDecor = RxnString();

  // ✅ Your shop catalog (local assets)
  final items = <ShopItem>[
    const ShopItem(
      id: 'food_apple',
      name: 'Apple',
      price: 5,
      category: ShopCategory.food,
      hunger: 10,
      asset: 'assets/shop/food/apple.png',
    ),
    const ShopItem(
      id: 'food_milk',
      name: 'Milk',
      price: 8,
      category: ShopCategory.food,
      hunger: 15,
      asset: 'assets/shop/food/milk.png',
    ),
    const ShopItem(
      id: 'food_bento',
      name: 'Bento',
      price: 15,
      category: ShopCategory.food,
      hunger: 25,
      asset: 'assets/shop/food/bento.png',
    ),
    const ShopItem(
      id: 'decor_lamp',
      name: 'Lamp',
      price: 30,
      category: ShopCategory.decor,
      asset: 'assets/shop/decor/lamp.png',
    ),
    const ShopItem(
      id: 'decor_plant',
      name: 'Plant',
      price: 25,
      category: ShopCategory.decor,
      asset: 'assets/shop/decor/plant.png',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    fetchInventory();
  }

  Future<String> _userIdOrGuest() async {
    final uid = await AuthStorage.readUserId();
    if (uid != null && uid.trim().isNotEmpty) return uid.trim();
    return 'guest-${DateTime.now().millisecondsSinceEpoch}';
  }

  // -------------------------
  // Inventory
  // -------------------------
  Future<void> fetchInventory() async {
    final token = await AuthStorage.readToken();
    if (token == null || token.isEmpty) return;

    final userId = await _userIdOrGuest();

    try {
      loading.value = true;
      final res = await _dio.dio.get('/shop/inventory/$userId');
      final data = (res.data is Map) ? res.data['data'] : null;
      if (data is! Map) return;

      final foods = Map<String, dynamic>.from(data['foods'] ?? {});
      final decors = Map<String, dynamic>.from(data['decors'] ?? {});

      foodsQty.assignAll(
        foods.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );

      decorsOwned.assignAll(
        decors.map((k, v) => MapEntry(k.toString(), v == true)),
      );

      activeDecor.value = data['active_decor']?.toString();
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ fetchInventory failed: $e');
    } finally {
      loading.value = false;
    }
  }

  // -------------------------
  // Purchase
  // -------------------------
  Future<void> purchase(ShopItem item) async {
    final token = await AuthStorage.readToken();
    if (token == null || token.isEmpty) {
      Get.snackbar("Login first 🦈", "Please login to use shop.");
      return;
    }

    // quick UI guard
    if (walletC.coins.value < item.price) {
      Get.snackbar("Not enough coins 🪙", "Earn more coins to buy ${item.name}!");
      return;
    }

    final userId = await _userIdOrGuest();

    try {
      loading.value = true;

      final res = await _dio.dio.post(
        '/shop/purchase',
        data: {
          "user_id": userId,
          "item_id": item.id,
          "item_type": item.type, // "food"/"decor"
          "price": item.price,
          "name": item.name,
        },
      );

      final data = (res.data is Map) ? res.data['data'] : null;
      if (data is Map && data['coins'] != null) {
        walletC.setCoins((data['coins'] as num).toInt());
      } else {
        await walletC.fetchBalance();
      }

      // Update inventory locally for snappy UI
      if (item.category == ShopCategory.food) {
        foodsQty[item.id] = (foodsQty[item.id] ?? 0) + 1;
      } else {
        decorsOwned[item.id] = true;
      }

      Get.snackbar("Purchased 🎉", "You bought ${item.name}!");
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ purchase failed: $e');
      Get.snackbar("Purchase failed", e.toString());
    } finally {
      loading.value = false;
    }
  }

  // -------------------------
  // Use food
  // -------------------------
  Future<void> useFood(ShopItem item) async {
    if (item.category != ShopCategory.food) return;

    final qty = foodsQty[item.id] ?? 0;
    if (qty <= 0) {
      Get.snackbar("No item 🥺", "You don't have ${item.name}.");
      return;
    }

    final userId = await _userIdOrGuest();

    try {
      loading.value = true;
      await _dio.dio.post('/shop/use-food', data: {
        "user_id": userId,
        "item_id": item.id,
      });

      foodsQty[item.id] = qty - 1;
      Get.snackbar("Nom nom 🦈", "${item.name} used! Hunger +${item.hunger}");
    } catch (e) {
      Get.snackbar("Use failed", e.toString());
    } finally {
      loading.value = false;
    }
  }

  // -------------------------
  // Equip decor
  // -------------------------
  Future<void> equipDecor(ShopItem item) async {
    if (item.category != ShopCategory.decor) return;

    final owned = decorsOwned[item.id] == true;
    if (!owned) {
      Get.snackbar("Not owned 🥺", "Buy it first!");
      return;
    }

    final userId = await _userIdOrGuest();

    try {
      loading.value = true;
      await _dio.dio.post('/shop/equip-decor', data: {
        "user_id": userId,
        "item_id": item.id,
      });

      activeDecor.value = item.id;
      Get.snackbar("Equipped ✨", "${item.name} is now active!");
    } catch (e) {
      Get.snackbar("Equip failed", e.toString());
    } finally {
      loading.value = false;
    }
  }

  bool isOwned(ShopItem item) => item.category == ShopCategory.food
      ? (foodsQty[item.id] ?? 0) > 0
      : (decorsOwned[item.id] == true);

  int qty(ShopItem item) => foodsQty[item.id] ?? 0;
}
