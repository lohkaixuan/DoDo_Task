// ==================================================
// Program Name   : authController.dart
// Purpose        : Manage authentication workflow (login, register, logout), token persistence, and user-scoped state reset using GetX.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 10 September 2025
// Last Modified  : 04 December 2025
// ==================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/api/apis.dart';
import 'package:v3/api/dioclient.dart';
import 'package:v3/controller/petController.dart';
import 'package:v3/controller/petMoodController.dart';
import 'package:v3/controller/shopController.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/controller/userController.dart';
import 'package:v3/controller/walletController.dart';
import 'package:v3/services/notification_service.dart';
import 'package:v3/storage/authStorage.dart';


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
        await AuthStorage.save(res.token!, res.id, res.email);
        isLoggedIn.value = true;

        await Get.find<UserController>().fetchMe();
        // ✅ after login fetch balance 
        await walletC.fetchBalance();
        await Get.find<TaskController>().fetchTasks();
        await Get.find<ShopController>().refreshAll();

        Get.offAllNamed('/home');
      } else {
        Get.snackbar("Login failed", "No token");
      }
    } catch (e) {
      Get.snackbar('Login error', 'Password does not match or user not found');
        //'Login error', e.toString());
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

  Future<void> logout() async {
    final notifier = Get.find<NotificationService>();
    final taskC = Get.find<TaskController>();

    isLoggedIn.value = false;

    await notifier.cancelAllNotifications();
    await taskC.clearAll();

    // ✅ RESET user-scoped controllers
    Get.find<UserController>().reset();
    Get.find<PetController>().reset();
    if (Get.isRegistered<ShopController>()) Get.find<ShopController>().reset();
    if (Get.isRegistered<PetController>()) Get.find<PetController>().reset();
    if (Get.isRegistered<PetMoodController>()) Get.find<PetMoodController>().reset();
    //Get.find<WalletController>().reset(); 

    await AuthStorage.clear();
    await AuthStorage.clearActiveUserKey();

    Get.offAllNamed('/login');
  }

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    super.onClose();
  }
}
