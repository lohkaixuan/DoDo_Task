// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api/dioclient.dart';
import 'controller/authController.dart';
import 'controller/settingController.dart';
import 'controller/taskController.dart';
import 'controller/petController.dart';
import 'controller/walletController.dart';
import 'services/notification_service.dart';
import 'package:get_storage/get_storage.dart';
import 'controller/insightsController.dart';

import 'route/page.dart';            // ← your AppPages (keep!)
import 'screens/focus_timer_screen.dart';
import 'binding/app_binding.dart';  // ← your AppBinding (keep!)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dodo Task',
      initialBinding: AppBinding(), // ✅ 全靠 Binding
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}

Future<bool> promptEnableNotificationsIfNeeded() async {
  final notifier = Get.find<NotificationService>();

  final enabled = await notifier.areEnabled();
  if (enabled) return true;

  final result = await Get.dialog<bool>(
    AlertDialog(
      title: const Text('Enable Notifications'),
      content: const Text(
        'To receive task reminders and focus alerts, '
        'please enable notifications.',
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () async {
            final ok = await notifier.ensurePermission();

            if (ok) {
              Get.back(result: true);
              Get.snackbar('Enabled 🎉', 'Task reminders are ready!');
            } else {
              final go = await Get.dialog<bool>(
                AlertDialog(
                  title: const Text('Notifications Disabled'),
                  content: const Text(
                    'Please enable notifications in App Settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              );

              if (go == true) {
                await notifier.openAppNotificationSettings();
              }
            }
          },
          child: const Text('Enable'),
        ),
      ],
    ),
  );

  return result ?? false;
}

/*class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      promptEnableNotificationsIfNeeded();
    });

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dodo Task',
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}*/