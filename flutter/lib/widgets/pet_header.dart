// ==================================================
// Program Name   : pet_header.dart
// Purpose        : Render the main pet header UI component showing pet sprite, mood, emotion level, and interactive animations on the dashboard.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 24 August 2025
// Last Modified  : 15 December 2025
// ==================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/petController.dart';
import 'package:v3/controller/petMoodController.dart';
import 'package:v3/controller/userController.dart';

class PetHeader extends StatefulWidget {
  const PetHeader({super.key, this.imageOverride, this.statusOverride});

  final String? imageOverride;
  final String? statusOverride;

  @override
  State<PetHeader> createState() => _PetHeaderState();
}

class _PetHeaderState extends State<PetHeader> {
  final user = Get.find<UserController>();
  final _rng = Random();
  Timer? _idleTimer;
  String? _bubble;
  Offset _pos = const Offset(16, 40);

  late final PetController _pet;

  @override
  void initState() {
    super.initState();
    _pet = Get.find<PetController>();
    _idleTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _randomTick());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  // =========================
  // Idle animation + bubble
  // =========================
  void _randomTick() {
    if (!mounted) return;

    // random walk
    if (_rng.nextDouble() < 0.25) {
      setState(() {
        _pos = _pos.translate(
          (_rng.nextDouble() * 40) - 20,
          (_rng.nextDouble() * 20) - 10,
        );
      });
    }

    // random speech bubble
    if (_rng.nextDouble() < 0.18) {
      final emo = _pet.emotion.value;
      final isSad = emo < 25;
      final isHappy = emo >= 75;

      final bank = isSad
          ? const [
              "Tiny step? 💪",
              "We’ll start small.",
              "Deep breath. You got this."
            ]
          : (isHappy
              ? const ["Nice streak! 🔥", "Proud of you 🎉", "Momentum GO! 🚀"]
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

  // =========================
  // Build
  // =========================
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final energy = _pet.emotion.value;

      // ✅ 核心：在这里读取，确保会刷新
      final petSprite =
          widget.imageOverride ?? _pet.currentSprite; // event > mood
      final decorSprite = _pet.equippedDecor.value; // lamp / plant
      final petMood = Get.isRegistered<PetMoodController>()
        ? Get.find<PetMoodController>()
        : null;

      final moodStr = petMood?.currentMood.value;

      return _buildContent(
        energy: energy,
        petSprite: petSprite,
        decorSprite: decorSprite,
      );
    });
  }

  Widget _buildContent({
    required int energy,
    required String petSprite,
    required String? decorSprite,
  }) {
    final isSad = energy < 25;
    final isHappy = energy >= 75;

    final moodLine = isSad
        ? "Feeling low… let's start tiny 💙"
        : (isHappy ? "Yay! Nice job 🎉" : "Let’s knock out one task 💪");

    final nameLine = user.displayName.isNotEmpty
        ? "Let’s go, ${user.displayName}! "
        : "Let’s go! ";

    final statusText = "$nameLine$moodLine";

    return SizedBox(
      height: 220,
      child: LayoutBuilder(builder: (context, box) {
        final maxX = (box.maxWidth - 128).clamp(0.0, double.infinity);
        final maxY = (box.maxHeight - 128).clamp(0.0, double.infinity);

        _pos = Offset(
          _pos.dx.clamp(0.0, maxX),
          _pos.dy.clamp(0.0, maxY),
        );

        return Stack(
          children: [
            // 🌈 Background
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

            // 📊 Emotion bar + status
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
                    child: LinearProgressIndicator(value: energy / 100),
                  ),
                  const SizedBox(height: 6),
                  Text(statusText),
                ],
              ),
            ),

            // 🪴 Decor overlay（不会替换宠物）
            if (decorSprite != null && decorSprite.isNotEmpty)
              Positioned(
                left: 12,
                bottom: 12,
                child: Image.asset(
                  decorSprite,
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),

            // 💬 Bubble
            if (_bubble != null)
              Positioned(
                left: (_pos.dx + 120).clamp(8, box.maxWidth - 200),
                top: (_pos.dy - 10).clamp(8, box.maxHeight - 60),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

            // 🐶 Pet
            Positioned(
              left: _pos.dx,
              top: _pos.dy,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() => _pos += d.delta),
                onTap: () => _showBubble(
                    isHappy ? "Woo! Keep going! 🎉" : "Hehe~ let's go!"),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: isHappy ? 1.08 : 1.0,
                  child: Image.asset(
                    petSprite,
                    width: 128,
                    height: 128,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
