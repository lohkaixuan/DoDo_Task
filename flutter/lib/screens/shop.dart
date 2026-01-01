// lib/screens/shop.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/shopController.dart';
import 'package:v3/models/shop_item.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Shop 🛍️"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: c.refreshAll,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: Obx(() {
        if (c.inventoryLoading.value && !c.inventoryReady.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final foods = c.items.where((x) => x.category == ShopCategory.food).toList();
        final decors = c.items.where((x) => x.category == ShopCategory.decor).toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _sectionTitle("Food 🍎"),
            _grid(foods, c),
            const SizedBox(height: 18),

            _sectionTitle("Decor ✨"),
            _grid(decors, c),
            const SizedBox(height: 12),

            if (c.activeDecor.value != null)
              Text(
                "Active decor: ${c.activeDecor.value}",
                style: const TextStyle(color: Colors.black54),
              ),
          ],
        );
      }),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          t,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );

  Widget _grid(List<ShopItem> items, ShopController c) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 250,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) => Obx(() => _itemCard(items[i], c)),
    );
  }

  Widget _itemCard(ShopItem it, ShopController c) {
    final ownedDecor = it.category == ShopCategory.decor ? c.isOwnedDecor(it) : false;
    final isActive = it.category == ShopCategory.decor ? c.isActiveDecor(it) : false;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(child: Image.asset(it.asset, fit: BoxFit.contain)),
            const SizedBox(height: 6),
            Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text("Price: ${it.price} 🪙"),

            if (it.category == ShopCategory.food)
              Text("Owned: ${c.qty(it)}", style: const TextStyle(color: Colors.black54)),

            const SizedBox(height: 10),

            // FOOD
            if (it.category == ShopCategory.food) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: c.loading.value ? null : () => c.purchase(it),
                      child: const Text("Buy"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (c.loading.value || c.qty(it) <= 0)
                          ? null
                          : () => c.useFood(it),
                      child: const Text("Use"),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // DECOR
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (c.loading.value || ownedDecor) ? null : () => c.purchase(it),
                  child: Text(ownedDecor ? "Owned" : "Buy"),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: (c.loading.value || !ownedDecor || isActive)
                      ? null
                      : () => c.equipDecor(it),
                  child: Text(isActive ? "Equipped" : "Equip"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
