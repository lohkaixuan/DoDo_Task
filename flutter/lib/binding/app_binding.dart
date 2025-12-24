// lib/binding/app_binding.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../api/dioclient.dart';
import '../controller/authController.dart';
import '../controller/insightsController.dart';
import '../controller/settingController.dart';
import '../controller/petController.dart';
import '../controller/taskController.dart';
import '../controller/walletController.dart';
import '../services/notification_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Storage
    if (!Get.isRegistered<GetStorage>()) {
      Get.put<GetStorage>(GetStorage(), permanent: true);
    }

    // Services
    Get.put<DioClient>(DioClient(), permanent: true);

    // ✅ NotificationService 已经在 main() put + await init 了
    // 这里不用再 putAsync / put
    // 但你可以确保它存在：
    Get.find<NotificationService>();

    // Controllers
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<PetController>(PetController(), permanent: true);
    Get.put<WalletController>(WalletController(), permanent: true);
    Get.put<SettingController>(SettingController(), permanent: true);

    Get.put<TaskController>(
      TaskController(Get.find<NotificationService>(), Get.find<PetController>()),
      permanent: true,
    );

    Get.put<InsightsController>(InsightsController(), permanent: true);
  }
}
