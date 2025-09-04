import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/authController.dart';

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
