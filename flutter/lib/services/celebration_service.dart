import 'package:just_audio/just_audio.dart';

class CelebrationService {
  CelebrationService._();
  static final CelebrationService _i = CelebrationService._();
  factory CelebrationService() => _i;

  final _player = AudioPlayer();

  Future<void> playSong(String assetPath) async {
    try {
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (_) {
      // swallow or log 
    }
  }

  Future<void> stop() => _player.stop();
  void dispose() => _player.dispose();
}
