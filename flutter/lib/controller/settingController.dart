// lib/controller/settingController.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SettingController extends GetxController {
  final GetStorage _box = GetStorage();

  // keys
  static const String _kMediumRepeatEnabled = 'mediumRepeatEnabled';
  static const String _kMediumRepeatHours = 'mediumRepeatHours';
  static const String _kLowRepeatEnabled = 'lowRepeatEnabled';
  static const String _kLowRepeatHours = 'lowRepeatHours';

  // defaults
  final RxBool mediumRepeatEnabled = false.obs;
  final RxInt mediumRepeatHours = 3.obs; // default 3 hours

  final RxBool lowRepeatEnabled = false.obs;
  final RxInt lowRepeatHours = 4.obs; // default 4 hours

  @override
  void onInit() {
    super.onInit();
    _load();
    _clampHours();
  }

  void _load() {
    // Type-safe reads (avoid unexpected dynamic issues)
    final mEnabled = _box.read(_kMediumRepeatEnabled);
    if (mEnabled is bool) mediumRepeatEnabled.value = mEnabled;

    final mHours = _box.read(_kMediumRepeatHours);
    if (mHours is int) mediumRepeatHours.value = mHours;

    final lEnabled = _box.read(_kLowRepeatEnabled);
    if (lEnabled is bool) lowRepeatEnabled.value = lEnabled;

    final lHours = _box.read(_kLowRepeatHours);
    if (lHours is int) lowRepeatHours.value = lHours;
  }

  void _clampHours() {
    // keep sane ranges
    mediumRepeatHours.value = mediumRepeatHours.value.clamp(1, 12);
    lowRepeatHours.value = lowRepeatHours.value.clamp(1, 12);
  }

  // -------------------------
  // Setters (persist + clamp)
  // -------------------------
  void setMediumEnabled(bool v) {
    mediumRepeatEnabled.value = v;
    _box.write(_kMediumRepeatEnabled, v);
  }

  void setMediumHours(int h) {
    mediumRepeatHours.value = h.clamp(1, 12);
    _box.write(_kMediumRepeatHours, mediumRepeatHours.value);
  }

  void setLowEnabled(bool v) {
    lowRepeatEnabled.value = v;
    _box.write(_kLowRepeatEnabled, v);
  }

  void setLowHours(int h) {
    lowRepeatHours.value = h.clamp(1, 12);
    _box.write(_kLowRepeatHours, lowRepeatHours.value);
  }
}
