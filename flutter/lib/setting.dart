// ==================================================
// Program Name   : setting.dart
// Purpose        : Provide the settings screen user interface, allowing users to configure preferences such as theme, notifications, and overlay behaviour.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 05 September 2025
// Last Modified  : 30 November 2025
// ==================================================


import 'package:flutter_overlay_window/flutter_overlay_window.dart';

Future<void> startFloatingPet() async {
  final ok = await FlutterOverlayWindow.isPermissionGranted();
  if (!ok) {
    await FlutterOverlayWindow.requestPermission();
  }
  await FlutterOverlayWindow.showOverlay(
    enableDrag: true,
    height: 200,
    width: 200,
    alignment: OverlayAlignment.centerRight,
    overlayTitle: "EchoPet",
    overlayContent: "echo_pet_overlay",
    flag: OverlayFlag.defaultFlag,
    visibility: NotificationVisibility.visibilityPublic,
  );
}

Future<void> stopFloatingPet() async {
  await FlutterOverlayWindow.closeOverlay();
}
