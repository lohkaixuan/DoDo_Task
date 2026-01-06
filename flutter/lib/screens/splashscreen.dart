// ==================================================
// Program Name   : splashscreen.dart
// Purpose        : Display splash screen during application startup, handling initial loading and navigation to authentication or home screen.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 18 August 2025
// Last Modified  : 20 November 2025
// ==================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/authController.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final auth = Get.find<AuthController>();
    // TODO: replace with your real token check logic
    //final hasToken = await auth.hasValidToken(); // implement in your controller
    // if (!mounted) return;
    // if (hasToken) {
    //   Get.offAllNamed('/home');
    // } else {
    //   Get.offAllNamed('/login');
    // }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
