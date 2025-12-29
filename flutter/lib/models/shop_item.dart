enum ShopItemType {food , decor}

class ShopItem {
  final String id;
  final String name;
  final int price;
  final ShopItemType type;
  final String emoji;

  const ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.type,
    required this.emoji,
  });
}