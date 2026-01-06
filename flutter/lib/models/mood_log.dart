// ==================================================
// Program Name   : mood_log.dart
// Purpose        : Define data model for user mood logs, including mood label, timestamp, confidence, and notes.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 02 October 2025
// Last Modified  : 18 November 2025
// ==================================================

class MoodLogReq {
  final String moodId;
  final String source; // user_slider
  final String label;  // positive/neutral/negative/anxious/tired
  final double confidence;
  final String? notes;

  MoodLogReq({
    required this.moodId,
    required this.source,
    required this.label,
    required this.confidence,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    "mood_id": moodId,
    "source": source,
    "label": label,
    "confidence": confidence,
    "notes": notes,
  };
}

class MoodLog {
  final String id;
  final DateTime ts;
  final String label;
  final int confidence;
  final String notes;
  final String source;

  MoodLog({
    required this.id,
    required this.ts,
    required this.label,
    required this.confidence,
    required this.notes,
    required this.source,
  });

  factory MoodLog.fromJson(Map<String, dynamic> j) {
    return MoodLog(
      id: (j['_id'] ?? '').toString(),
      ts: DateTime.tryParse((j['ts'] ?? '').toString()) ?? DateTime.now(),
      label: (j['label'] ?? 'unknown').toString(),
      confidence: (j['confidence'] is num) ? (j['confidence'] as num).toInt() : 0,
      notes: (j['notes'] ?? '').toString(),
      source: (j['source'] ?? '').toString(),
    );
  }
}
