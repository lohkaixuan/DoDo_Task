import 'package:get/get.dart';

class SettingController extends GetxController {
  // medium/low repeating reminders allowed?
  final mediumRepeatEnabled = true.obs;
  final lowRepeatEnabled = false.obs;

  // (optional) let user also decide repeat frequency for medium/low
  final mediumRepeatHours = 3.obs; // example
  final lowRepeatHours = 6.obs;    // example
}