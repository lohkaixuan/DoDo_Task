import 'package:dodotask/screen/login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

import 'api/dioclient.dart';
import 'controller/authController.dart';
import 'controller/taskController.dart';
import 'controller/petController.dart';
import 'controller/userController.dart';
import 'route/pages.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final dio = DioClient();
  Get.put<DioClient>(dio, permanent: true);

  Get.put<AuthGetxController>(AuthGetxController(), permanent: true);

  Get.put<PetController>(PetController(dio), permanent: true); // register pet first
  Get.put<TaskController>(TaskController(dio, Get.find<PetController>()), permanent: true);
  Get.put(UserController()); // global singleton

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DODO Task',
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}