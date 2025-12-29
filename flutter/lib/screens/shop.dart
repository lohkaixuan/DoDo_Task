// lib/screens/shop.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/shopController.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ prefer find; if not exists then put
    final ShopController c = Get.isRegistered<ShopController>()
        ? Get.find<ShopController>()
        : Get.put(ShopController());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Shop 🦈"),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Food"),
              Tab(text: "Decor"),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () async {
                await c.fetchShop();
                await c.fetchInventory();
              },
              icon: const Icon(Icons.refresh),
            )
          ],
        ),
        body: Obx(() {
          if (c.loading.value && c.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final foods = c.items.where((x) => x.type == 'food').toList();
          final decors = c.items.where((x) => x.type == 'decor').toList();

          return TabBarView(
            children: [
              _grid(context, c, foods),
              _grid(context, c, decors),
            ],
          );
        }),
      ),
    );
  }

  Widget _grid(BuildContext context, ShopController c, List<ShopItem> list) {
    if (list.isEmpty) {
      return const Center(child: Text("No items yet."));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final it = list[i];
        final icon = it.type == 'food' ? Icons.fastfood : Icons.chair_alt;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 8),
                Text(
                  it.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text("Price: ${it.price} 🪙"),
                if (it.type == 'food' && it.hunger > 0)
                  Text("Hunger +${it.hunger}"),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: c.loading.value ? null : () => c.purchase(it),
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text("Buy"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
