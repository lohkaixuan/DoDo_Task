// lib/models/shop_item.dart
enum ShopCategory { food, decor }

class ShopItem {
  final String id;
  final ShopCategory category;
  final String name;
  final int price;
  final int hunger; // only for food (optional)
  final String asset; // Image.asset path

  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.price,
    required this.asset,
    this.hunger = 0,
  });

  // For local items (recommended)
  static List<ShopItem> defaults() => const [
        // Food
        ShopItem(
          id: "apple",
          category: ShopCategory.food,
          name: "Apple",
          price: 5,
          hunger: 8,
          asset: "assets/shop/food/apple.png",
        ),
        ShopItem(
          id: "milk",
          category: ShopCategory.food,
          name: "Milk",
          price: 7,
          hunger: 10,
          asset: "assets/shop/food/milk.png",
        ),
        ShopItem(
          id: "bento",
          category: ShopCategory.food,
          name: "Bento",
          price: 12,
          hunger: 18,
          asset: "assets/shop/food/bento.png",
        ),

        // Decor
        ShopItem(
          id: "lamp",
          category: ShopCategory.decor,
          name: "Lamp",
          price: 30,
          asset: "assets/shop/decor/lamp.png",
        ),
        ShopItem(
          id: "plant",
          category: ShopCategory.decor,
          name: "Plant",
          price: 25,
          asset: "assets/shop/decor/plant.png",
        ),
      ];

  String get itemTypeString => category == ShopCategory.food ? "food" : "decor";
}
