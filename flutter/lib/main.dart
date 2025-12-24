// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'binding/app_binding.dart';
import 'services/notification_service.dart';
import 'route/page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // ✅ 先注册并 init NotificationService（避免 putAsync race）
  final notifier = Get.put(NotificationService(), permanent: true);
  await notifier.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dodo Task',
      initialBinding: AppBinding(), // ✅ 用 binding 注入其它依赖
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
