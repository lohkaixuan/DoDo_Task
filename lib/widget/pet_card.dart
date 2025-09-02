// lib/widgets/pet_card.dart
import 'package:flutter/material.dart';
import '../models/pet_risk.dart';

IconData _reactionIcon(String r) {
  switch (r) {
    case 'concern': return Icons.sentiment_dissatisfied_rounded;
    case 'cheer': return Icons.emoji_emotions_rounded;
    case 'happy': return Icons.tag_faces_rounded;
    default: return Icons.pets_rounded;
  }
}

class PetCard extends StatelessWidget {
  final PetRisk? risk;
  final VoidCallback onTapViewTask;
  const PetCard({super.key, required this.risk, required this.onTapViewTask});

  @override
  Widget build(BuildContext context) {
    final score = risk?.score ?? 0;
    final reaction = risk?.reaction ?? 'idle';
    final suggestion = risk?.suggestion ?? "You're doing great—keep steady 💪";

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF5C45FF),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // left: text + button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your buddy notices:",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: const Color(0xFF5C45FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onTapViewTask,
                  child: const Text("View Task"),
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          // right: ring + icon
          Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76, height: 76,
                    child: CircularProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  Text("${score.toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Icon(_reactionIcon(reaction), color: Colors.white, size: 28),
            ],
          ),
        ],
      ),
    );
  }
}
