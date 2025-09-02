// lib/models/pet_risk.dart
class PetRisk {
  final double score;                 // 0–100
  final String reaction;              // happy/cheer/concern/idle
  final String suggestion;
  final Map<String, dynamic> signals;

  PetRisk({required this.score, required this.reaction, required this.suggestion, required this.signals});

  factory PetRisk.fromJson(Map<String, dynamic> j) => PetRisk(
    score: (j['score'] as num).toDouble(),
    reaction: (j['pet_reaction'] ?? 'idle').toString(),
    suggestion: (j['suggestion'] ?? '').toString(),
    signals: (j['signals'] as Map?)?.cast<String, dynamic>() ?? {},
  );
}
