import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/petController.dart';

/// Header with a cute pet + emotion bar (0..100).
/// - If [imageOverride] provided, uses that sprite; else picks by mood.
/// - [statusOverride] can replace the status line.
class PetHeader extends StatefulWidget {
  const PetHeader({super.key, this.imageOverride, this.statusOverride});

  final String? imageOverride;
  final String? statusOverride;

  @override
  State<PetHeader> createState() => _PetHeaderState();
}

class _PetHeaderState extends State<PetHeader> {
  final _rng = Random();
  Timer? _idleTimer;
  String? _bubble;
  Offset _pos = const Offset(16, 40);

  PetController? _pet;
String _spriteFromEmotion(int emotion) {
  // you can tweak thresholds and file names
  if (emotion >= 75) return 'assets/happy.gif';
  if (emotion >= 40) return 'assets/sad.png';
  return 'assets/sad.png';
}

  @override
  void initState() {
    super.initState();
    _pet = Get.isRegistered<PetController>() ? Get.find<PetController>() : null;
    _idleTimer = Timer.periodic(const Duration(seconds: 4), (_) => _randomTick());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _randomTick() {
    if (!mounted) return;

    // small random walk
    if (_rng.nextDouble() < 0.25) {
      setState(() {
        final dx = (_rng.nextDouble() * 40) - 20;
        final dy = (_rng.nextDouble() * 20) - 10;
        _pos = _pos.translate(dx, dy);
      });
    }

    // random bubble
    if (_rng.nextDouble() < 0.18) {
      final emo = _pet?.emotion.value ?? 60;
      final isSad = emo < 25;
      final isHappy = emo >= 75;
      final bank = isSad
          ? const ["Tiny step? 💪", "We’ll start small.", "Deep breath. You got this."]
          : (isHappy
              ? const ["Nice streak! 🔥", "Proud of you 🎉", "Momentum GO! 🚀"]
              : const ["Let’s do one task!", "Hydration check 💧", "Stretch time? 🧘"]);
      _showBubble(bank[_rng.nextInt(bank.length)]);
    }
  }

  void _showBubble(String text) {
    setState(() => _bubble = text);
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _bubble = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pet == null) {
      return _buildContent(energy: 60);
    }
    return Obx(() => _buildContent(energy: _pet!.emotion.value));
  }

  Widget _buildContent({required int energy}) {
    final isSad = energy < 25;
    final isHappy = energy >= 75;

    // Pick sprite: prefer override else mood-based
    final petImg = widget.imageOverride ??
        (isSad ? 'assets/sad.png' : (isHappy ? 'assets/eat.gif' : 'assets/move.gif'));

    final statusText = widget.statusOverride ??
        (isSad ? "Feeling low… let's start tiny 💙" : (isHappy ? 'Yay! Nice job 🎉' : 'Let’s knock out one task 💪'));

    return SizedBox(
      height: 220,
      child: LayoutBuilder(builder: (context, box) {
        final maxX = (box.maxWidth - 128).clamp(0.0, double.infinity);
        final maxY = (box.maxHeight - 128).clamp(0.0, double.infinity);
        final clamped = Offset(
          _pos.dx.clamp(0.0, maxX).toDouble(),
          _pos.dy.clamp(0.0, maxY).toDouble(),
        );
        if (clamped != _pos) _pos = clamped;

        return Stack(
          children: [
            // background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.lightBlue.shade100, Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Emotion + status
            Positioned(
              left: 16,
              right: 16,
              top: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Companion', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: energy / 100.0),
                  ),
                  const SizedBox(height: 6),
                  Text(statusText),
                ],
              ),
            ),

            // Speech bubble
            if (_bubble != null)
              Positioned(
                left: (_pos.dx + 128 - 12).clamp(8, box.maxWidth - 208),
                top: (_pos.dy - 8).clamp(8, box.maxHeight - 60),
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                    ),
                    child: Text(_bubble!, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),

            // Draggable pet
            Positioned(
              left: _pos.dx,
              top: _pos.dy,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() => _pos += d.delta),
                onTap: () => _showBubble(isHappy ? "Woo! Keep going! 🎉" : "Hehe~ let's go!"),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: isHappy ? 1.08 : 1.0,
                  curve: Curves.easeOut,
                  child: Image.asset(petImg, width: 128, height: 128),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
