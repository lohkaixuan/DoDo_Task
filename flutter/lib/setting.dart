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
