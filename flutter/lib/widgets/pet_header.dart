import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/petController.dart';

/// Header with a cute pet + energy bar.
/// - You can override the sprite via [imageOverride] (used by FocusTimerScreen).
/// - You can override the status text via [statusOverride].
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

  // Pet position inside the header
  Offset _pos = const Offset(16, 40);

  PetController? _petC;

  @override
  void initState() {
    super.initState();
    _petC = Get.isRegistered<PetController>() ? Get.find<PetController>() : null;
    _idleTimer = Timer.periodic(const Duration(seconds: 4), (_) => _randomTick());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _randomTick() {
    if (!mounted) return;

    // 25% random walk
    if (_rng.nextDouble() < 0.25) {
      setState(() {
        final dx = (_rng.nextDouble() * 40) - 20;
        final dy = (_rng.nextDouble() * 20) - 10;
        _pos = _pos.translate(dx, dy);
      });
    }

    // 18% speak a short phrase
    if (_rng.nextDouble() < 0.18) {
      final petHappy = _petC?.petHappy.value ?? true;
      final energy = _petC?.petEnergy.value ?? 100;
      final isSad = !petHappy && energy < 20;
      final bank = isSad
          ? const [
              "Tiny step? 💪",
              "We’ll start small.",
              "Deep breath. You got this."
            ]
          : (petHappy
              ? const [
                  "Nice streak! 🔥",
                  "Proud of you 🎉",
                  "Momentum GO! 🚀"
                ]
              : const [
                  "Let’s do one task!",
                  "Hydration check 💧",
                  "Stretch time? 🧘"
                ]);
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
    // If we have a PetController, react to it. Otherwise render a static header.
    if (_petC == null) {
      return _buildContent(
        energy: 100,
        happy: true,
      );
    }
    return Obx(() => _buildContent(
          energy: _petC!.petEnergy.value,
          happy: _petC!.petHappy.value,
        ));
  }

  Widget _buildContent({required int energy, required bool happy}) {
    final isSad = !happy && energy < 20;

    // Pick sprite: prefer override (Focus/Mode), else mood-based fallback
    final petImg = widget.imageOverride ??
        (isSad
            ? 'assets/sad.png'
            : (happy ? 'assets/eat.gif' : 'assets/move.gif'));

    final statusText = widget.statusOverride ??
        (isSad
            ? "Feeling low… let's start tiny 💙"
            : (happy ? 'Yay! Nice job 🎉' : 'Let’s knock out one task 💪'));

    return SizedBox(
      height: 220,
      child: LayoutBuilder(builder: (context, box) {
        // clamp inside header
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

            // Energy + status
            Positioned(
              left: 16,
              right: 16,
              top: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Companion',
                      style: TextStyle(fontWeight: FontWeight.w600)),
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(blurRadius: 6, color: Colors.black26)
                      ],
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
                onTap: () {
                  setState(() => _pos = _pos.translate(12, 0));
                  _showBubble(happy ? "Woo! Keep going! 🎉" : "Hehe~ let's go!");
                },
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: happy ? 1.08 : 1.0,
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
