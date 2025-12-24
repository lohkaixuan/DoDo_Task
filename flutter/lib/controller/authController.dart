import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/walletController.dart';
import '../api/dioclient.dart';
import '../api/apis.dart';
import '../storage/authStorage.dart';

class AuthController extends GetxController {
  final DioClient dioClient = Get.find<DioClient>(); // ✅ use injected
  late final WalletController walletC;

  // form controllers owned by GetX (UI stays thin)
  final email = TextEditingController();
  final password = TextEditingController();

  final isLoading = false.obs;
  final isLoggedIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    walletC = Get.find<WalletController>();
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      var res = await ApiService(dioClient).login(email, password);

      if (res.token != null && res.token!.isNotEmpty) {
        await AuthStorage.save(res.token, res.id, res.email);

        // ✅ 登录成功后再打 balance（这才是最稳的时机）
        await walletC.fetchBalance();

        Get.offAllNamed('/home');
      } else {
        Get.snackbar("Login failed", "No token");
      }
    } catch (e) {
      Get.snackbar('Login error', e.toString());
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
