// ==================================================
// Program Name   : app_binding.dart
// Purpose        : Register and inject core services/controllers using GetX bindings, ensuring global dependencies are initialized consistently.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 01 September 2025
// Last Modified  : 15 December 2025
// ==================================================

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:v3/api/dioclient.dart';
import 'package:v3/controller/authController.dart';
import 'package:v3/controller/graphController.dart';
import 'package:v3/controller/insightsController.dart';
import 'package:v3/controller/moodController.dart'; 
import 'package:v3/controller/petController.dart';
import 'package:v3/controller/petMoodController.dart';
import 'package:v3/controller/settingController.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/controller/userController.dart';
import 'package:v3/controller/walletController.dart';
import 'package:v3/controller/shopController.dart';
import 'package:v3/services/notification_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Core singletons
    Get.put<DioClient>(DioClient(), permanent: true);

    final notifier = Get.find<NotificationService>();

    // Controllers (permanent = never auto delete)
    Get.put<WalletController>(WalletController(), permanent: true);
    Get.put<SettingController>(SettingController(), permanent: true);
    Get.put<PetController>(PetController(), permanent: true);
    Get.put<PetMoodController>(PetMoodController(), permanent: true);
    Get.put<UserController>(UserController(),permanent: true);
    Get.put<ShopController>(ShopController(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);    

    // Other controllers
    Get.lazyPut<GraphController>(() => GraphController(), fenix: true);
    Get.lazyPut<MoodController>(() => MoodController(), fenix: true);

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

