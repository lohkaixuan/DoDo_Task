// lib/models/shop_item.dart
enum ShopCategory { food, decor }

class ShopItem {
  final String id; // backend: item_id
  final String name;
  final ShopCategory category;
  final int price;
  final String asset;
  final int hunger; // only for food (optional)

  const ShopItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.asset,
    this.hunger = 0,
  });

  factory ShopItem.fromJson(Map<String, dynamic> j) {
    final catRaw = (j['category'] ?? '').toString().toLowerCase();
    final cat = (catRaw == 'decor') ? ShopCategory.decor : ShopCategory.food;

    return ShopItem(
      id: (j['item_id'] ?? j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      category: cat,
      price: (j['price'] is num) ? (j['price'] as num).toInt() : int.tryParse('${j['price']}') ?? 0,
      asset: (j['asset'] ?? '').toString(),
      hunger: (j['hunger'] is num) ? (j['hunger'] as num).toInt() : int.tryParse('${j['hunger']}') ?? 0,
    );
  }
}
