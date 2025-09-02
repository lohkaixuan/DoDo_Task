import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../api/dioclient.dart';
import '../api/apis.dart';
import '../route/pages.dart';

class AuthGetxController extends GetxController {
  final dioClient = DioClient();

  // form controllers owned by GetX (UI stays thin)
  final email = TextEditingController();
  final password = TextEditingController();

  final isLoading = false.obs;
  final isLoggedIn = false.obs;

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      Get.snackbar('Login', 'Please enter email and password');
      return;
    }
    // try {
    //   isLoading.value = true;
    //   // final res = await client.dio.post(
    //   //   //Apis.authLogin, // '/auth/login'
    //   //   //data: {'email': email.text.trim(), 'password': password.text},
    //   // );

    //   if (res.statusCode == 200) {
    //     isLoggedIn.value = true;
    //     //Get.offAllNamed(AppRoutes.todo);
    //   } else {
    //     Get.snackbar('Login failed', 'Server rejected the credentials');
    //   }
    // } catch (e) {
    //   Get.snackbar('Login error', e.toString());
    // } finally {
    //   isLoading.value = false;
    // }
  }

  Future<void> register(String email, String password, String name) async {
    try {
      isLoading.value = true;
      var res = await ApiService(dioClient).register(email, password, name);
      if (res.status == 'success') {
        Get.snackbar('Register', 'Registration successful. Please log in.');
        Get.toNamed('/login');
      } else {
        Get.snackbar('Register failed', res.message);
      }
    } catch (e) {
      Get.snackbar('Register error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void logout() {
    isLoggedIn.value = false;
    //Get.offAllNamed(AppRoutes.login);
  }

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    super.onClose();
  }
}
