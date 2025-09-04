import 'package:get/get.dart';

enum PetEmotionFlag {
  idle,          // baseline
  start,         // user started something
  focus,         // during focus
  nudging,       // reminder
  late,          // overdue
  completedEarly,
  completedOnTime,
  completedLate,
  tired,         // too much continuous work
  happy,         // emotion high but healthy
  sad,           // emotion low
}

class PetController extends GetxController {
  // Main emotion meter (0..100). Daily refresh at midnight.
  final emotion = 60.obs;       // baseline start
  final exp = 0.obs;            // experience points
  final level = 1.obs;
  final fatigueMinutes = 0.obs; // continuous focus minutes (resets on break)
  DateTime _lastEmotionDay = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // Call this in app foreground / on tick
  void tickDailyRefresh() {
    final today = _today();
    if (today.isAfter(_lastEmotionDay)) {
      // Daily decay towards 60 (neutral), clamp in [0,100]
      final current = emotion.value;
      final diff = current - 60;
      final newVal = (current - diff * 0.7).round(); // soften towards baseline
      emotion.value = newVal.clamp(0, 100);
      fatigueMinutes.value = 0;
      _lastEmotionDay = today;
    }
  }

  void setEmotionFlag(PetEmotionFlag flag) {
    // Simple flag to let your UI swap pet images/animations
    // You can store it if you want:
    // currentFlag.value = flag;
  }
 String get currentSprite {
    final e = emotion.value; // 0..100 (you already expose this)
    // pick your own files here:
    if (e >= 80) return 'assets/dance.gif';
    if (e >= 50) return 'assets/eat.gif';
    if (e >= 25) return 'assets/sad.png';
    return 'assets/pet/sad.png';
  }
  void addExp(int points) {
    exp.value += points;
    // small emotion boost for gaining XP
    _bumpEmotion(2);
    // level up each 100 XP (simple rule)
    while (exp.value >= level.value * 100) {
      exp.value -= level.value * 100;
      level.value += 1;
      _bumpEmotion(5); // happy ping on level up
    }
  }

  void onFocusStart(int minutesPlanned) {
    setEmotionFlag(PetEmotionFlag.focus);
  }

  void onFocusAccumulate(int seconds) {
    fatigueMinutes.value += (seconds / 60).floor();
    // If continuous work exceeds healthy window, reduce emotion slightly
    if (fatigueMinutes.value >= 120) {
      // 2 hours continuous → tired
      setEmotionFlag(PetEmotionFlag.tired);
      _dropEmotion(1);
    }
  }

  void onFocusPauseOrBreak() {
    fatigueMinutes.value = 0;
  }

  void onTaskStarted() {
    setEmotionFlag(PetEmotionFlag.start);
    _bumpEmotion(1);
  }

  void onTaskCompleted({required bool early, required bool onTime, required bool late}) {
    if (early) {
      setEmotionFlag(PetEmotionFlag.completedEarly);
      _bumpEmotion(6);
      addExp(20);
    } else if (onTime) {
      setEmotionFlag(PetEmotionFlag.completedOnTime);
      _bumpEmotion(4);
      addExp(15);
    } else if (late) {
      setEmotionFlag(PetEmotionFlag.completedLate);
      _dropEmotion(6);
      addExp(8);
    }
    _normalizeFeeling();
  }

  void onTaskLate() {
    setEmotionFlag(PetEmotionFlag.late);
    _dropEmotion(4);
  }

  void nudge() {
    setEmotionFlag(PetEmotionFlag.nudging);
  }

  // Helpers
  void _bumpEmotion(int n) {
    emotion.value = (emotion.value + n).clamp(0, 100);
  }

  void _dropEmotion(int n) {
    emotion.value = (emotion.value - n).clamp(0, 100);
  }

  void _normalizeFeeling() {
    // if too high for long, pet can feel “overstimulated → sad/tired”
    if (emotion.value >= 90 && fatigueMinutes.value >= 180) {
      // 3h continuous at very high emotion
      setEmotionFlag(PetEmotionFlag.tired);
      _dropEmotion(10);
    }
    if (emotion.value <= 20) {
      setEmotionFlag(PetEmotionFlag.sad);
    } else if (emotion.value >= 80) {
      setEmotionFlag(PetEmotionFlag.happy);
    }
  }
}
