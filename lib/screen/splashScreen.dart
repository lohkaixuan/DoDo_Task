import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../route/pages.dart';
import '../controller/petController.dart'; // <-- IMPORTANT

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // initialize PetController after the widget is mounted
    Future.microtask(() => context.read<PetController>().init())
        .then((_) => _routeNext());
  }

  Future<void> _routeNext() async {
    // TODO: check auth; for now go to todo
    // Using GetX routing if you prefer:
    Get.offAllNamed("/login");
    //if (!mounted) return;
    //Navigator.of(context).pushReplacementNamed(AppRoutes.todo);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
