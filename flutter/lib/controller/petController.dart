// ==================================================
// Program Name   : petController.dart
// Purpose        : Manage virtual pet core logic including mood, emotion score, events, fatigue, experience, level progression, and pet sprites.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 20 August 2025
// Last Modified  : 12 December 2025
// ==================================================

import 'dart:async';
import 'package:get/get.dart';

enum PetMood { idle, sad, focus, tired, rest }
enum PetEvent { dance, eat, drink, walk }

class PetController extends GetxController {
  // -------------------------
  // Score system
  // -------------------------
  final emotion = 40.obs; // 0..100
  final exp = 0.obs;
  final level = 1.obs;

  // -------------------------
  // Mood + event
  // -------------------------
  final mood = PetMood.idle.obs;
  final event = Rxn<PetEvent>();
  Timer? _eventTimer;

  // -------------------------
  // Fatigue
  // -------------------------
  final fatigueMinutes = 0.obs;

  // -------------------------
  // Sprites
  // -------------------------
  final currentPetSprite = 'assets/idle.png'.obs; // PET base
  final equippedDecor = ''.obs; // DECOR overlay (empty = none)

  static const _moodAsset = {
    PetMood.idle: 'assets/idle.png',
    PetMood.sad: 'assets/sad.png',
    PetMood.focus: 'assets/study.png',
    PetMood.tired: 'assets/tired.png',
    PetMood.rest: 'assets/wellness.png',
  };

  static const _eventAsset = {
    PetEvent.dance: 'assets/dance.gif',
    PetEvent.eat: 'assets/eat.gif',
    PetEvent.walk: 'assets/move.gif',
    PetEvent.drink: 'assets/drink.png',
  };

  /// ✅ Priority: Event > Pet > Mood
  /// Decor should be drawn as overlay in UI (NOT replacing the pet).
  String get currentSprite {
    final e = event.value;
    if (e != null) return _eventAsset[e]!;
    // show pet sprite if you have one
    final pet = currentPetSprite.value;
    if (pet.isNotEmpty) return pet;
    // fallback mood icon
    return _moodAsset[mood.value]!;
  }

  /// Decor overlay path (empty string = none)
  String get decorSprite => equippedDecor.value;

  bool get hasDecor => equippedDecor.value.isNotEmpty;

  // -------------------------
  // Public APIs
  // -------------------------
  void equipPet(String petAsset) {
    currentPetSprite.value = petAsset;
  }

  void equipDecor(String assetPath) {
    equippedDecor.value = assetPath; // ✅ only set decor
  }

  void unequipDecor() {
    equippedDecor.value = ''; // ✅ NOT null
  }

  void reset() {
    emotion.value = 50;
    exp.value = 0;
    level.value = 1;

    fatigueMinutes.value = 0;

    event.value = null;
    mood.value = PetMood.idle;

    // keep pet sprite as default or keep current — your choice:
    currentPetSprite.value = 'assets/idle.png';

    // remove decor
    equippedDecor.value = '';

    _eventTimer?.cancel();
    _eventTimer = null;
  }

  // -------------------------
  // Core helpers
  // -------------------------
  void addMood(int delta) {
    emotion.value = (emotion.value + delta).clamp(0, 100);
    _recalcMoodFromScore();
  }

  void _recalcMoodFromScore() {
    // if focus/rest, don't override
    if (mood.value == PetMood.focus || mood.value == PetMood.rest) return;

    final s = emotion.value;
    if (s <= 30) {
      mood.value = PetMood.sad;
    } else if (s <= 45) {
      mood.value = PetMood.tired;
    } else {
      mood.value = PetMood.idle;
    }
  }

  void playEvent(PetEvent e, {Duration duration = const Duration(seconds: 3)}) {
    _eventTimer?.cancel();
    event.value = e;
    _eventTimer = Timer(duration, () => event.value = null);
  }

  // -------------------------
  // Hooks (Task/Shop)
  // -------------------------
  void onTaskStarted() => addMood(1);

  void onTaskLate() {
    addMood(-8);
    playEvent(PetEvent.walk, duration: const Duration(seconds: 2));
  }

  void onTaskCompleted() {
    addMood(8);
    playEvent(PetEvent.dance, duration: const Duration(seconds: 2));
  }

  // -------------------------
  // EXP + Level
  // -------------------------
  void addExp(int points) {
    exp.value += points;
    addMood(2);

    while (exp.value >= level.value * 100) {
      exp.value -= level.value * 100;
      level.value += 1;
      addMood(5);
      playEvent(PetEvent.dance, duration: const Duration(seconds: 2));
    }
  }

  // -------------------------
  // Focus timer hooks
  // -------------------------
  void onFocusStart([int minutesPlanned = 25]) => mood.value = PetMood.focus;

  void onFocusAccumulate(int seconds) {
    fatigueMinutes.value += (seconds / 60).floor();
    if (fatigueMinutes.value >= 120) {
      mood.value = PetMood.tired;
      addMood(-1);
    }
  }

  void onFocusPauseOrBreak() {
    fatigueMinutes.value = 0;
    mood.value = PetMood.idle;
    _recalcMoodFromScore();
  }

  @override
  void onClose() {
    _eventTimer?.cancel();
    super.onClose();
  }
}
