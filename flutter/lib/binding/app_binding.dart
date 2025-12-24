import 'package:get/get.dart';
import 'package:v3/controller/walletController.dart';
import '../api/dioclient.dart';
import '../controller/authController.dart';
import '../controller/insightsController.dart';
import '../controller/settingController.dart';
import '../services/notification_service.dart';
import '../controller/petController.dart';
import '../controller/taskController.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.put<DioClient>(DioClient(), permanent: true);
    Get.put<NotificationService>(NotificationService(), permanent: true);

    // Controllers (no dependencies / light deps)
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<PetController>(PetController(), permanent: true);
    Get.put<SettingController>(SettingController(), permanent: true);
    Get.put<WalletController>(WalletController(), permanent: true);

    // Controllers that depend on others
    Get.put<TaskController>(
      TaskController(Get.find<NotificationService>(), Get.find<PetController>()),
      permanent: true,
    );

    Get.put<InsightsController>(InsightsController(), permanent: true);

    // init notifier here (optional)
    Get.find<NotificationService>().init();
  }
}
