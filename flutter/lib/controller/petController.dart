import 'package:get/get.dart';

class PetController extends GetxController {
  final petEnergy = 0.obs; // 0..100
  final petHappy  = false.obs;

  void setHappy(bool v) => petHappy.value = v;
  void setEnergy(int v) => petEnergy.value = v.clamp(0, 100);
  void adjustEnergy(int delta) => setEnergy(petEnergy.value + delta);
}
