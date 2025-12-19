import 'dart:async';
import 'package:get/get.dart';

enum PetMood { idle, sad, focus, tired, rest }
enum PetEvent { dance, eat, drink, walk }

class PetController extends GetxController {
  // --- score system ---
  final emotion = 40.obs; // 0..100 mood score
  final exp = 0.obs;
  final level = 1.obs;

  // --- persistent mood + temporary event ---
  final mood = PetMood.idle.obs;
  final event = Rxn<PetEvent>();
  Timer? _eventTimer;

  // fatigue tracking for long focus
  final fatigueMinutes = 0.obs;
  DateTime _lastEmotionDay = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // Assets mapping (based on your list)
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

  String get currentSprite {
    final e = event.value;
    if (e != null) return _eventAsset[e]!;
    return _moodAsset[mood.value]!;
  }

  // ---------- Daily refresh ----------
  void tickDailyRefresh() {
    final today = _today();
    if (today.isAfter(_lastEmotionDay)) {
      // drift emotion back toward 60
      final current = emotion.value;
      final diff = current - 60;
      final newVal = (current - diff * 0.7).round();
      emotion.value = newVal.clamp(0, 100);
      fatigueMinutes.value = 0;
      _lastEmotionDay = today;
      _recalcMoodFromScore();
    }
  }

  // ---------- core helpers ----------
  void _bumpEmotion(int n) {
    emotion.value = (emotion.value + n).clamp(0, 100);
    _recalcMoodFromScore();
  }

  void _dropEmotion(int n) {
    emotion.value = (emotion.value - n).clamp(0, 100);
    _recalcMoodFromScore();
  }

  void _recalcMoodFromScore() {
    // if currently focus/rest, don't override until ended
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

  // =========================================================
  // ✅ Compatibility methods (keep your existing calls working)
  // =========================================================

  void addExp(int points) {
    exp.value += points;
    _bumpEmotion(2);
    while (exp.value >= level.value * 100) {
      exp.value -= level.value * 100;
      level.value += 1;
      _bumpEmotion(5);
      // small celebration on level up
      playEvent(PetEvent.dance, duration: const Duration(seconds: 2));
    }
  }

  // Focus timer calls these:
  void onFocusStart([int minutesPlanned = 25]) {
    mood.value = PetMood.focus;
  }


  void onFocusAccumulate(int seconds) {
    fatigueMinutes.value += (seconds / 60).floor();
    if (fatigueMinutes.value >= 120) {
      mood.value = PetMood.tired;
      _dropEmotion(1);
    }
  }

  void onFocusPauseOrBreak() {
    fatigueMinutes.value = 0;
    // If paused, go back to idle (or score-based mood)
    mood.value = PetMood.idle;
    _recalcMoodFromScore();
  }

  // Task triggers (你完成加分 / 拖延扣分)
  void onTaskStarted() => _bumpEmotion(1);

  void onTaskLate() => _dropEmotion(4);
  void onTaskDelayed() => onTaskLate();

  void onTaskCompleted({required bool early, required bool onTime, required bool late, bool allDailyDone = false}) {
    if (early) {
      _bumpEmotion(6);
      addExp(20);
    } else if (onTime) {
      _bumpEmotion(4);
      addExp(15);
    } else if (late) {
      _dropEmotion(6);
      addExp(8);
    }
    if (allDailyDone) {
      playEvent(PetEvent.dance, duration: const Duration(seconds: 4));
    }
  }

  // Extra events
  void onRestStart() => mood.value = PetMood.rest;
  void onRestEnd() { mood.value = PetMood.idle; _recalcMoodFromScore(); }

  void onShopOpen() => playEvent(PetEvent.eat, duration: const Duration(seconds: 3));
  void onDrinkReminder() => playEvent(PetEvent.drink, duration: const Duration(seconds: 2));
  void randomWalk() => playEvent(PetEvent.walk, duration: const Duration(seconds: 5));

  @override
  void onClose() {
    _eventTimer?.cancel();
    super.onClose();
  }
}
