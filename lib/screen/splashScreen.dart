// lib/screen/splashScreen.dart
import 'dart:async'; // <-- for TimeoutException
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/apis.dart';
import '../controller/userController.dart';
import '../storage/authStorage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final ApiService api = Get.find<ApiService>();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // brief splash feel
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // 1) read token from secure storage (with one-time migration from prefs)
      String? token = await AuthStorage.readToken();

      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString('token'); // old key (if you used it before)
        if (legacy != null && legacy.isNotEmpty) {
          token = legacy;
          // write to secure storage + clean up
          await AuthStorage.save(legacy, (await AuthStorage.readUserId()) ?? '');
          await prefs.remove('token');
        }
      }

      // 2) if still no token -> go login
      if (token == null || token.isEmpty) {
        Get.offAllNamed('/login');
        return;
      }

      // 3) try to rotate token, but give up after 5 seconds
      final resp = await api
          .loginWithToken(token)
          .timeout(const Duration(seconds: 5)); // <-- hard timeout

      // 4) save new token & go home
      await AuthStorage.save(resp.token, resp.id);
      Get.find<UserController>().setUser(resp.id, resp.email);
      Get.offAllNamed('/home', arguments: {'userId': resp.id});
    } on TimeoutException {
      // took longer than 5s: don't clear token; just go login
      Get.offAllNamed('/login');
    } catch (_) {
      // invalid/expired token etc.
      await AuthStorage.clear();
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // centered splash image
            Image.asset(
              'assets/splash.png',   // <-- put your image here
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
