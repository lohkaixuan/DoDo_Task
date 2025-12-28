import 'package:just_audio/just_audio.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final AudioPlayer _player = AudioPlayer();

  // ✅ 改成你的 Render 后端
  final String baseUrl = "https://dodo-task-1.onrender.com";

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    try {
      if (_player.playing) await _player.stop();

      final url = "$baseUrl/tts/speak?text=${Uri.encodeComponent(t)}";
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      // ignore: avoid_print
      print("❌ TTS speak error: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}

