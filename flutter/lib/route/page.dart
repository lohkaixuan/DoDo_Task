import 'package:get/get.dart';


import '../screens/home_screen.dart';
import '../screens/login.dart';
import '../screens/register.dart';
//import '../screens/splash_screen.dart';


class AppPages {
  // ignore: constant_identifier_names
    // final userC = Get.find<UserController>();

  static const initial = '/login';

  static final routes = [
    // GetPage(
    //   name: '/splashscreen',
    //   page: () => SplashScreen(
    //     title: "Welcome to ITSU APP",
    //   ),
    // ),
    GetPage(
      name: '/login',
      page: () => LoginPage(),
    ),
    GetPage(
      name: '/register',
      page: () => RegisterPage(),
    ),
    GetPage(
      name: '/home',
      page: () => HomePage(),
    ),
    // GetPage(
    //   name: '/group_tasks',
    //   page: () {
    //     final args = Get.arguments as Map<String, dynamic>?;
    //     final userId = args?['userId'] ?? '';
    //     final category = args?['category'] ?? 'General';
    //     return GroupTasksPage(userId: userId, category: category, taskC: null,);
    //   },
    // ),
    // GetPage(
    //   name: '/focus_timer',
    //   page: () {
    //     final args = Get.arguments as Map<String, dynamic>?;
    //     final taskId = args?['taskId'] ?? '';
    //     final taskTitle = args?['taskTitle'] ?? 'Focus Task';
    //     return FocusTimerPage(taskId: taskId, taskTitle: taskTitle, task: null, userId: userC.userId.value,);
    //   },
    // ),
    
  ];
}
