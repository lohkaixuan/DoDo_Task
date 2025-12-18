import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/walletController.dart';
import '../api/dioclient.dart';
import '../api/apis.dart';
import '../storage/authStorage.dart';

class AuthController extends GetxController {
  final dioClient = DioClient();

  // form controllers owned by GetX (UI stays thin)
  final email = TextEditingController();
  final password = TextEditingController();

  final isLoading = false.obs;
  final isLoggedIn = false.obs;

  Future<void> login(String email, String password) async {
    print("login called $email $password");
    try {
      isLoading.value = true;
      var res = await ApiService(dioClient).login(email, password);

      if (res.message.contains("success")) {
        Get.snackbar('Login', 'Login successful');
        await AuthStorage.save(res.token, res.id,res.email);
        final walletC = Get.find<WalletController>();
        await walletC.fetchBalance();
        Get.offAllNamed('/home');
      } else {
        Get.snackbar('Login failed', 'Server rejected the credentials');
      }
    } catch (e) {
      Get.snackbar('Login error', e.toString());
      print("login error $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register(String email, String password, String name) async {
    try {
      isLoading.value = true;
      var res = await ApiService(dioClient).register(email, password, name);
      if (res.message .contains("success")) {
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
