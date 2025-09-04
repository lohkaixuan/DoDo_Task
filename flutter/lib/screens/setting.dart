import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/taskController.dart';
import '../../controller/petController.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final pet = Get.find<PetController>();
    final tc = Get.find<TaskController>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // --- Demo data / maintenance ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Data', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          tc.seedDemo();
                          Get.snackbar('Seeded', 'Demo tasks created',
                              snackPosition: SnackPosition.BOTTOM);
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Seed demo data'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          tc.clearAll();
                          Get.snackbar('Cleared', 'All tasks removed',
                              snackPosition: SnackPosition.BOTTOM);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear all tasks'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Pet controls ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Obx(() {
                final emotion = pet.emotion.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pet', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Emotion'),
                      subtitle: Text('Current: $emotion / 100'),
                      trailing: FilledButton(
                        onPressed: () {
                          pet.emotion.value = 20; // daily refresh baseline
                          Get.snackbar('Pet', 'Emotion reset to 60',
                              snackPosition: SnackPosition.BOTTOM);
                        },
                        child: const Text('Reset daily'),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // --- About ---
          Card(
            child: ListTile(
              title: const Text('About'),
              subtitle: const Text('DoDo Task — demo settings'),
              trailing: const Icon(Icons.info_outline),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
