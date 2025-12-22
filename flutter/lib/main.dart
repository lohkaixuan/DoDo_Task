// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api/dioclient.dart';
import 'controller/authController.dart';
import 'controller/taskController.dart';
import 'controller/petController.dart';
import 'controller/walletController.dart';
import 'services/notification_service.dart';

import 'route/page.dart';            // ← your AppPages (keep!)
import 'screens/focus_timer_screen.dart';
import 'binding/app_binding.dart';  // ← your AppBinding (keep!)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Services
  final notifier = Get.put<NotificationService>(
    NotificationService(),
    permanent: true,
  );
  Get.put<DioClient>(DioClient(), permanent: true);

  // Controllers
  Get.put<WalletController>(WalletController(), permanent: true);
  Get.put<AuthController>(AuthController(), permanent: true);
  Get.put<PetController>(PetController(), permanent: true);
  Get.put<TaskController>(
    TaskController(Get.find<NotificationService>(), Get.find<PetController>()),
    permanent: true,
  );

  await notifier.init();

  runApp(const MyApp());
}

Future<void> promptEnableNotificationsIfNeeded() async {
  final notifier = Get.find<NotificationService>();

  final enabled = await notifier.areEnabled();
  if (enabled) return;

  Get.dialog(
    AlertDialog(
      title: const Text('Enable Notifications'),
      content: const Text(
        'To receive task reminders and focus alerts, please enable notifications.',
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () async {
            final ok = await notifier.ensurePermission();
            Get.back();

            if (!ok) {
              Get.snackbar(
                'Permission not granted',
                'You can enable it in Settings > Apps > Notifications.',
                snackPosition: SnackPosition.BOTTOM,
              );
            } else {
              Get.snackbar(
                'Enabled!',
                'Task reminders are ready 🦈',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
          child: const Text('Enable'),
        ),
      ],
    ),
    barrierDismissible: true,
  );
}

class MyApp extends StatelessWidget {
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
}