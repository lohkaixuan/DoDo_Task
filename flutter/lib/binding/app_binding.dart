import 'package:get/get.dart';
import '../services/notification_service.dart';
import '../controller/petController.dart';
import '../controller/taskController.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.put<NotificationService>(NotificationService(), permanent: true);

    // Controllers
    Get.put<PetController>(PetController(), permanent: true);
    Get.put<TaskController>(
      TaskController(
        Get.find<NotificationService>(),
        Get.find<PetController>(),
      ),
      permanent: true,
    );
  }
}
