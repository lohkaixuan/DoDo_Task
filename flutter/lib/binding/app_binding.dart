// lib/binding/app_binding.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:v3/api/dioclient.dart';
import 'package:v3/controller/authController.dart';
import 'package:v3/controller/insightsController.dart'; 
import 'package:v3/controller/petController.dart';
import 'package:v3/controller/settingController.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/controller/walletController.dart';
import 'package:v3/services/notification_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    //Get.put<GetStorage>(GetStorage(), permanent: true);
    Get.put<DioClient>(DioClient(), permanent: true);

    final notifier = Get.isRegistered<NotificationService>()
        ? Get.find<NotificationService>()
        : Get.put(NotificationService(), permanent: true);

    // ORDER MATTERS
    Get.put<WalletController>(WalletController(), permanent: true);
    Get.put<SettingController>(SettingController(), permanent: true);
    Get.put<PetController>(PetController(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);

    Get.lazyPut<TaskController>(
      () => TaskController(notifier, Get.find<PetController>()),
      fenix: true,
    );

    Get.put<InsightsController>(InsightsController(), permanent: true);

    print("has WalletController? ${Get.isRegistered<WalletController>()}");
    print("has AuthController? ${Get.isRegistered<AuthController>()}");
    print("has TaskController? ${Get.isRegistered<TaskController>()}");
    print("has NotificationService? ${Get.isRegistered<NotificationService>()}");
  }
}

