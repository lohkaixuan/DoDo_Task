import 'package:get/get.dart';

import '../screen/register.dart';
import '../screen/login.dart';
//import '../screens/splash_screen.dart';

class AppPages {
  // ignore: constant_identifier_names
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
      page: () => const LoginPage(),
    ),
    GetPage(
      name: '/register',
      page: () => const RegisterPage(),
    ),
  ];
  
}