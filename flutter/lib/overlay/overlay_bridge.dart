// lib/overlay/overlay_bridge.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:v3/services/tts_service.dart';

class PetBridge {
  PetBridge._();
  static final PetBridge instance = PetBridge._();

  /// Widgets in-app can listen to show the speech bubble.
  final ValueNotifier<String?> lastSpeech = ValueNotifier<String?>(null);

  /// Speak in-app (TTS + bubble) and forward to overlay if it’s running.
  Future<void> say(String text) async {
    final msg = text.trim();
    if (msg.isEmpty) return;

    // In-app TTS + bubble
    await TtsService.instance.speak(msg);
    lastSpeech.value = msg;

    // Overlay bubble + TTS
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData(
          jsonEncode({'type': 'say', 'text': msg}),
        );
      }
    } catch (_) {}
  }

  /// Tell the overlay to celebrate (play song + show GIF/Lottie/WebP).
  Future<void> celebrate({
    String song = 'assets/tell-me-what.mp3',
    String gif  = 'assets/dance.gif', // transparent background recommended
    int seconds = 5,
  }) async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData(
          jsonEncode({
            'type': 'celebrate',
            'song': song,
            'gif': gif,
            'seconds': seconds,
          }),
        );
      }
    } catch (_) {}
  }
}

/// Convenience helpers
Future<void> petSay(String text) => PetBridge.instance.say(text);
Future<void> petCelebrate({
  String song = 'assets/tell-me-what.mp3',
  String gif  = 'assets/dance.gif',
  int seconds = 5,
}) => PetBridge.instance.celebrate(song: song, gif: gif, seconds: seconds);
