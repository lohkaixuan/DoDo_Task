// lib/main.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'binding/app_binding.dart';
import 'services/notification_service.dart';
import 'route/page.dart';

Future<void> main() async {
  // ✅ 关键：所有东西都在同一个 zone 里面做
  runZonedGuarded(() async {
    BindingBase.debugZoneErrorsAreFatal = true;
    WidgetsFlutterBinding.ensureInitialized();
    await GetStorage.init();

    // 可选：把 Flutter framework error 也打印出来
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };

    // ✅ 只初始化一次 NotificationService
    final notifier = Get.put(NotificationService(), permanent: true);
    await notifier.init();

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint("💥 ZONE ERROR: $error");
    debugPrint("$stack");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dodo Task',
      initialBinding: AppBinding(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
