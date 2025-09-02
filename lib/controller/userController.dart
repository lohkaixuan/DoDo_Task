// lib/controller/user_controller.dart
import 'package:get/get.dart';

class UserController extends GetxController {
  var userId = ''.obs;
  var email = ''.obs;

  void setUser(String id, String mail) {
    userId.value = id;
    email.value = mail;
  }

  void clearUser() {
    userId.value = '';
    email.value = '';
  }
}
