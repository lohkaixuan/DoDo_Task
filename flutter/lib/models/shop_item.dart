// lib/models/shop_item.dart
enum ShopCategory { food, decor }

class ShopItem {
  final String id;        // e.g. "food_apple"
  final String name;      // e.g. "Apple"
  final int price;        // coins
  final ShopCategory category;
  final int hunger;       // only for food (0 for decor)
  final String asset;     // local asset path

  const ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.asset,
    this.hunger = 0,
  });

  String get type => category == ShopCategory.food ? "food" : "decor";
}
