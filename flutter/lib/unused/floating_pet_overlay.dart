// lib/overlay/floating_pet_overlay.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Floating, draggable pet overlay.
///
/// Start with:
/// FlutterOverlayWindow.showOverlay(
///   enableDrag: true,
///   height: 180, width: 180,
///   alignment: OverlayAlignment.centerRight,
///   overlayContent: 'overlayMain', // matches @pragma in main.dart
/// );
class FloatingPetOverlay extends StatefulWidget {
  const FloatingPetOverlay({super.key});

  @override
  State<FloatingPetOverlay> createState() => _FloatingPetOverlayState();
}

class _FloatingPetOverlayState extends State<FloatingPetOverlay> {
  final _tts = FlutterTts();
  StreamSubscription<dynamic>? _sub;

  // Bubble state
  String _bubble = '';
  bool _bubbleVisible = false;
  Timer? _bubbleTimer;

  // Simple celebrate swap
  bool _celebrating = false;
  String _petAsset = 'assets/move.gif';
  String _celebrateAsset = 'assets/dance.gif';
  Timer? _celebrateTimer;

  @override
  void initState() {
    super.initState();
    _initTts();
    _listen();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  void _listen() {
    _sub = FlutterOverlayWindow.overlayListener.listen((event) async {
      try {
        final Map<String, dynamic> data = switch (event) {
          final String s => (jsonDecode(s) as Map).cast<String, dynamic>(),
          final Map m => m.cast<String, dynamic>(),
          _ => const {},
        };

        switch (data['type']) {
          case 'say':
            final text = (data['text'] ?? '').toString();
            if (text.isEmpty) return;
            _showBubble(text);
            await _tts.stop();
            await _tts.speak(text);
            break;

          case 'celebrate':
            final gif = (data['gif'] as String?) ?? _celebrateAsset;
            final seconds = (data['seconds'] as int?) ?? 5;
            _startCelebrate(gif, seconds);
            break;

          case 'close':
            await FlutterOverlayWindow.closeOverlay();
            break;

          case 'ping':
            _showBubble('pong');
            break;
        }
      } catch (_) {}
    });
  }

  void _showBubble(String text) {
    setState(() {
      _bubble = text;
      _bubbleVisible = true;
    });
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _bubbleVisible = false);
    });
  }

  void _startCelebrate(String gif, int seconds) {
    setState(() {
      _celebrateAsset = gif;
      _celebrating = true;
    });
    _celebrateTimer?.cancel();
    _celebrateTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      setState(() => _celebrating = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bubbleTimer?.cancel();
    _celebrateTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sprite = _celebrating ? _celebrateAsset : _petAsset;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                spreadRadius: 1,
                offset: Offset(0, 2),
                color: Colors.black26,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- BUBBLE ON TOP ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _bubbleVisible
                    ? Container(
                        key: const ValueKey('bubble'),
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          _bubble,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Pet sprite below bubble
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  sprite,
                  width: 148,
                  height: 100,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(height: 6),

              // Controls
              Row(
                children: [
                  IconButton(
                    tooltip: 'Say hi',
                    icon: const Icon(Icons.chat_bubble_rounded),
                    onPressed: () async {
                      const text = "Hi! I'm floating here.";
                      _showBubble(text);
                      await _tts.stop();
                      await _tts.speak(text);
                    },
                  ),
                  IconButton(
                    tooltip: 'Celebrate',
                    icon: const Icon(Icons.celebration),
                    onPressed: () => _startCelebrate(_celebrateAsset, 5),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Drag this card to move',
                    icon: const Icon(Icons.drag_indicator),
                    onPressed: () {},
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () async => FlutterOverlayWindow.closeOverlay(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
