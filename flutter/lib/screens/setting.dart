import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/taskController.dart';
import '../../controller/petController.dart';
import '../services/notification_service.dart';


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

          // --- Logout ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Logout'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Get.deleteAll(force: true);
                        Get.offAllNamed('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
           Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('test', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Logout'),
                    trailing: ElevatedButton(
                      onPressed: () async {
                       await Get.find<NotificationService>().testNow();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('test'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
