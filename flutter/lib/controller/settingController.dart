// lib/controller/settingController.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SettingController extends GetxController {
  final _box = GetStorage();

  // keys
  static const _kMediumRepeatEnabled = 'mediumRepeatEnabled';
  static const _kMediumRepeatHours = 'mediumRepeatHours';
  static const _kLowRepeatEnabled = 'lowRepeatEnabled';
  static const _kLowRepeatHours = 'lowRepeatHours';

  // defaults
  final mediumRepeatEnabled = false.obs;
  final mediumRepeatHours = 3.obs; // default 3 hours

  final lowRepeatEnabled = false.obs;
  final lowRepeatHours = 4.obs; // default 4 hours

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    mediumRepeatEnabled.value =
        _box.read(_kMediumRepeatEnabled) ?? mediumRepeatEnabled.value;
    mediumRepeatHours.value =
        _box.read(_kMediumRepeatHours) ?? mediumRepeatHours.value;

    lowRepeatEnabled.value =
        _box.read(_kLowRepeatEnabled) ?? lowRepeatEnabled.value;
    lowRepeatHours.value = _box.read(_kLowRepeatHours) ?? lowRepeatHours.value;

    _clampHours();
  }

  void _clampHours() {
    // keep sane ranges
    mediumRepeatHours.value = mediumRepeatHours.value.clamp(1, 12);
    lowRepeatHours.value = lowRepeatHours.value.clamp(1, 12);
  }

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
