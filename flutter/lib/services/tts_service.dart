// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  Future<void> _ensureInit() async {
    if (_inited) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _inited = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // swallow; device may not have TTS engine
    }
  }

  Future<void> stop() async {
    try { await _tts.stop(); } catch (_) {}
  }
}