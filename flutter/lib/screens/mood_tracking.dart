// lib/screens/mood_tracking.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/moodController.dart';
import '../models/mood_log.dart';

class MoodTrackingPage extends StatelessWidget {
  const MoodTrackingPage({super.key});

  String _emoji(String label) {
    switch (label) {
      case "positive": return "😊";
      case "neutral": return "😐";
      case "negative": return "😞";
      case "anxious": return "😰";
      case "tired": return "🥱";
      default: return "🙂";
    }
  }

  String _fmt(DateTime dt) {
    // simple formatting without extra packages
    String two(int n) => n.toString().padLeft(2, "0");
    return "${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<MoodController>()
        ? Get.find<MoodController>()
        : Get.put(MoodController());

    final moods = const [
      ("positive", "Positive"),
      ("neutral", "Neutral"),
      ("negative", "Negative"),
      ("anxious", "Anxious"),
      ("tired", "Tired"),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mood Tracking"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: c.fetchHistory,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh history",
          ),
        ],
      ),
      body: Obx(() => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text(
                "How do you feel today?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: moods.map((m) {
                  final key = m.$1;
                  final label = m.$2;
                  final selected = c.selected.value == key;

                  return ChoiceChip(
                    label: Text("${_emoji(key)} $label"),
                    selected: selected,
                    onSelected: (_) => c.selected.value = key,
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),
              TextField(
                controller: c.notesCtrl, // ✅ bind controller so we can clear UI
                decoration: const InputDecoration(
                  labelText: "Notes (optional)",
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
                onChanged: (v) => c.notes.value = v,
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: c.loading.value ? null : c.submit,
                  icon: const Icon(Icons.save),
                  label: Text(c.loading.value ? "Saving..." : "Save Mood"),
                ),
              ),

              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Recent History", style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),

              if (c.loadingHistory.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (c.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text("No mood logs yet. Try logging one! 😊"),
                )
              else
                ...c.history.map((MoodLog m) => _historyTile(m, _emoji, _fmt)),
            ],
          )),
    );
  }

  static Widget _historyTile(
    MoodLog m,
    String Function(String) emoji,
    String Function(DateTime) fmt,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji(m.label), style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${m.label} • ${fmt(m.ts)}",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (m.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(m.notes, style: const TextStyle(color: Colors.black54)),
                  ],
                ],
              ),
            ),
            Text(
              "c:${m.confidence}",
              style: const TextStyle(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
