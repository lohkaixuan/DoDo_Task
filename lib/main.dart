import 'package:dodotask/screen/login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

import 'api/dioclient.dart';
import 'controller/authController.dart';
import 'controller/todoController.dart';
import 'controller/petController.dart';
import 'route/pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // before runApp
   runApp(const MyApp());
  Get.put(AuthGetxController());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {


    // create your DioClient once and pass into controllers
    final client = DioClient();

    return MultiProvider(
      providers: [
        //ChangeNotifierProvider(create: (_) => AuthController(client)),
        ChangeNotifierProvider(create: (_) => TodoController(client)),
        ChangeNotifierProvider(create: (_) => PetController()),
      ],
      child: Builder(
        // << ensure we have a context under providers
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<PetController>().init();
          });
          return GetMaterialApp(
            title: 'DODO Task',
            debugShowCheckedModeBanner: false,
            initialRoute: AppPages.initial,   // <- use your route constants
            getPages: AppPages.routes,        // <- defined in route/pages.dart
            // theme: AppTheme().theme,        // hook your theme later
          );
        },
      ),
    );
  }
}
