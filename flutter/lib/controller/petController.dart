// lib/controller/petController.dart
import 'dart:async';
import 'package:get/get.dart';

enum PetMood { idle, sad, focus, tired, rest }
enum PetEvent { dance, eat, drink, walk }

class PetController extends GetxController {
  // score system
  final emotion = 40.obs; // 0..100
  final exp = 0.obs;
  final level = 1.obs;

  // mood + event
  final mood = PetMood.idle.obs;
  final event = Rxn<PetEvent>();
  Timer? _eventTimer;

  // fatigue
  final fatigueMinutes = 0.obs;

  // decor (equipped sprite path)
  final equippedDecor = RxnString();

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

  /// ✅ Priority: Event > Equipped > Mood
  String get currentSprite {
    final e = event.value;
    if (e != null) return _eventAsset[e]!;
    return _moodAsset[mood.value]!;
  }

  // =========================
  // Core helpers
  // =========================
  void addMood(int delta) {
    emotion.value = (emotion.value + delta).clamp(0, 100);
    _recalcMoodFromScore();
  }

  void _recalcMoodFromScore() {
    // if focus/rest, don't override
    if (mood.value == PetMood.focus || mood.value == PetMood.rest) return;

    final s = emotion.value;
    if (s <= 30) mood.value = PetMood.sad;
    else if (s <= 45) mood.value = PetMood.tired;
    else mood.value = PetMood.idle;
  }

  void playEvent(PetEvent e, {Duration duration = const Duration(seconds: 3)}) {
    _eventTimer?.cancel();
    event.value = e;
    _eventTimer = Timer(duration, () => event.value = null);
  }

  // =========================
  // Hooks (Task/Shop)
  // =========================
  void onTaskStarted() => addMood(1);

  void onTaskLate() {
    addMood(-8);
    playEvent(PetEvent.walk, duration: const Duration(seconds: 2));
  }

  void onTaskCompleted() {
    addMood(8);
    playEvent(PetEvent.dance, duration: const Duration(seconds: 2));
  }

  // =========================
  // EXP + Level
  // =========================
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

  // =========================
  // Focus timer hooks
  // =========================
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

  // =========================
  // Decor API
  // =========================
  void equipDecor(String assetPath) => equippedDecor.value = assetPath;
  void unequipDecor() => equippedDecor.value = null;

  @override
  void onClose() {
    _eventTimer?.cancel();
    super.onClose();
  }
}
