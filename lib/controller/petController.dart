import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PetController extends ChangeNotifier with WidgetsBindingObserver {
  String mood = 'neutral';
  int coins = 0;   // lifetime coins (not reset daily by default)
  int streak = 0;

  DateTime? _lastReset;      // local date we last reset
  Timer? _midnightTimer;

  static const _kMood = 'pet_mood';
  static const _kCoins = 'pet_coins';
  static const _kStreak = 'pet_streak';
  static const _kLastReset = 'pet_last_reset_ms';

  // Call once (e.g., after Providers are mounted)
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _loadState();
    await _maybeDailyReset();      // in case app launched after midnight
    _scheduleMidnightRefresh();    // schedule next midnight tick
  }

  // App lifecycle: when user returns to app, re-check daily reset
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeDailyReset();
      _scheduleMidnightRefresh();
    }
  }

  // === Public API ===

  /// Reward loop when a task is completed
  void onTaskCompleted() {
    coins += 1;
    mood = 'happy';
    _saveState();
    notifyListeners();
  }

  /// Gentle overdue support flow
  void markOverdueSupport() {
    mood = 'sleepy';
    _saveState();
    notifyListeners();
  }

  void setMood(String value) {
    mood = value;
    _saveState();
    notifyListeners();
  }

  /// Optional: call this once/day when user has met daily goal to advance streak.
  void markDailyGoalDone() {
    final today = _localToday();
    // only increment once per day
    if (_lastReset == null || !_isSameDate(_lastReset!, today)) {
      // if yesterday → keep streak growing; if gap > 1 day → reset to 1
      if (_lastReset != null &&
          _isSameDate(_lastReset!, today.subtract(const Duration(days: 1)))) {
        streak += 1;
      } else {
        streak = 1;
      }
      _lastReset = today;
      _saveState();
      notifyListeners();
    }
  }

  // === Daily reset core ===
  Future<void> _maybeDailyReset() async {
    final today = _localToday();
    if (_lastReset == null || !_isSameDate(_lastReset!, today)) {
      // what resets daily? keep coins lifetime; reset mood only (customize as needed)
      mood = 'neutral';
      // if you track "dailyCoins" or "dailyTasks", reset them here.
      _lastReset = today;
      await _saveState();
      notifyListeners();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final next = _nextMidnight(now);
    final dur = next.difference(now);
    _midnightTimer = Timer(dur, () async {
      await _maybeDailyReset();
      _scheduleMidnightRefresh(); // schedule the next day
    });
  }

  // === Persistence ===
  Future<void> _loadState() async {
    final sp = await SharedPreferences.getInstance();
    mood = sp.getString(_kMood) ?? 'neutral';
    coins = sp.getInt(_kCoins) ?? 0;
    streak = sp.getInt(_kStreak) ?? 0;
    final ms = sp.getInt(_kLastReset);
    _lastReset = (ms == null) ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _saveState() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kMood, mood);
    await sp.setInt(_kCoins, coins);
    await sp.setInt(_kStreak, streak);
    await sp.setInt(_kLastReset, (_lastReset ?? _localToday()).millisecondsSinceEpoch);
  }

  // === Helpers ===
  DateTime _localToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _nextMidnight(DateTime from) =>
      DateTime(from.year, from.month, from.day).add(const Duration(days: 1));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }
}
