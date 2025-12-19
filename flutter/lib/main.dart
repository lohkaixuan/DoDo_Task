// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:collection/collection.dart';

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
  Get.put<NotificationService>(NotificationService(), permanent: true);
  Get.put<DioClient>(DioClient(), permanent: true);

  // Controllers
  Get.put<WalletController>(WalletController(), permanent: true);
  Get.put<AuthController>(AuthController(), permanent: true);
  Get.put<PetController>(PetController(), permanent: true);
  Get.put<TaskController>(
    TaskController(Get.find<NotificationService>(), Get.find<PetController>()),
    permanent: true,
  );

  // Handle notification taps -> Focus screen
  await Get.find<NotificationService>().init(
    onSelectPayload: (payload) async {
      final taskId = payload;
      final tc = Get.find<TaskController>();
      final t = tc.tasks.firstWhereOrNull((x) => x.id == taskId);
      if (t != null) {
        Get.toNamed('/focus', arguments: {'taskId': t.id});
      }
    },
  );

  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dodo Task',
      initialRoute: AppPages.initial,   // '/login' for now (you can switch to '/splash')
      getPages: AppPages.routes,
    );
  }
}