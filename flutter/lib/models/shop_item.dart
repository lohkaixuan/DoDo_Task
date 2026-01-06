// ==================================================
// Program Name   : shop_item.dart
// Purpose        : Define shop item model and static catalog configuration, including food and decor item metadata.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 30 August 2025
// Last Modified  : 25 November 2025
// ==================================================

enum ShopCategory { food, decor }

class ShopItem {
  final String id;
  final String name;
  final int price;
  final ShopCategory category;
  final String asset; // Image.asset path

  const ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.asset,
  });
}

class ShopCatalog {
  static const items = <ShopItem>[
    // Food
    ShopItem(
      id: "apple",
      name: "Apple",
      price: 5,
      category: ShopCategory.food,
      asset: "assets/shop/food/apple.png",
    ),
    ShopItem(
      id: "milk",
      name: "Milk",
      price: 7,
      category: ShopCategory.food,
      asset: "assets/shop/food/milk.png",
    ),
    ShopItem(
      id: "bento",
      name: "Bento",
      price: 12,
      category: ShopCategory.food,
      asset: "assets/shop/food/bento.png",
    ),

    // Decor
    ShopItem(
      id: "lamp",
      name: "Lamp",
      price: 30,
      category: ShopCategory.decor,
      asset: "assets/shop/decor/lamp.png",
    ),
    ShopItem(
      id: "plant",
      name: "Plant",
      price: 25,
      category: ShopCategory.decor,
      asset: "assets/shop/decor/plant.png",
    ),
  ];
}
