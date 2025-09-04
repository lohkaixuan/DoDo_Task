import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/petController.dart';
import 'package:v3/controller/taskController.dart';
import 'api/dioclient.dart';
import 'controller/authController.dart'; // keep if you have it
import 'route/page.dart';
import 'screens/focus_timer_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(DioClient(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(TaskController(), permanent: true);
  await Get.find<TaskController>().seedIfEmpty();
await NotificationService.instance.init(onSelectTask: (taskId) async {
  final tc = Get.find<TaskController>();
  final t = tc.all.firstWhereOrNull((x) => x.id == taskId);
  if (t != null) Get.to(() => FocusTimerScreen(task: t, autoStart: false));
});

  Get.put(PetController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dodo Task',
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
// If you have an overlay entrypoint, it runs in a separate isolate.
// Re-register what's needed there too.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(DioClient(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(TaskController(), permanent: true);
  Get.put(PetController(), permanent: true);
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: Text('Overlay running'))),
  ));
}