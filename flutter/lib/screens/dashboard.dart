// ==================================================
// Program Name   : dashboard.dart
// Purpose        : Serve as the main dashboard screen that summarizes task statistics, virtual pet status, AI insights, and user wellbeing information.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 26 August 2025
// Last Modified  : 15 December 2025
// ==================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/insightsController.dart';
import 'package:v3/controller/moodController.dart';
import 'package:v3/controller/petMoodController.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/controller/userController.dart';
import 'package:v3/models/task.dart';
import 'package:v3/widgets/coin_badge.dart';
import 'package:v3/widgets/pad.dart';
import 'package:v3/widgets/pet_header.dart';
import 'package:v3/widgets/task_list_tile.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Get.find<UserController>();
    final tc = Get.find<TaskController>();
    final petMood = Get.find<PetMoodController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          CoinBadge(),
          SizedBox(width: 16),
        ],
      ),
      body: Obx(() {
        final all = tc.tasks;
        final now = DateTime.now();

        final notStarted =
            all.where((t) => t.computeStatus(now) == TaskStatus.notStarted).length;
        final inProgress =
            all.where((t) => t.computeStatus(now) == TaskStatus.inProgress).length;
        final completed =
            all.where((t) => t.status == TaskStatus.completed).length;
        final late =
            all.where((t) => t.computeStatus(now) == TaskStatus.late).length;

        final total =
            (notStarted + inProgress + completed + late).clamp(1, 999999);
        double pct(int v) => v / total;

        final rec = tc.recommended(max: 5);

        return ListView(
          padding: padAll(context, h: 16, v: 16),
          children: [
            // 👋 Greeting
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                user.displayName.isNotEmpty
                    ? "Hi ${user.displayName} 👋"
                    : "Hi there 👋",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),

            // 🐶 Pet Header
            const PetHeader(),

            const SizedBox(height: 12),

            // 📊 Task Stats
            _taskStatsCard(
              notStarted: notStarted,
              inProgress: inProgress,
              completed: completed,
              late: late,
              pct: pct,
            ),

            const SizedBox(height: 12),

            // 🤖 AI Insights
            const InsightsCard(),

            const SizedBox(height: 12),

            // ⭐ Recommended Tasks
            _recommendedCard(rec),

            const SizedBox(height: 12),

            // 🐾 Pet Mood Logs
            _petMoodCard(petMood),

            const SizedBox(height: 12),

            // 🧠 User Mood
            _userMoodCard(),

            const SizedBox(height: 100),
          ],
        );
      }),
    );
  }

  // ========================
  // Widgets below
  // ========================

  Widget _taskStatsCard({
    required int notStarted,
    required int inProgress,
    required int completed,
    required int late,
    required double Function(int) pct,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Task Stats',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _DonutPainter([
                  (pct(notStarted), Colors.grey),
                  (pct(inProgress), Colors.blue),
                  (pct(completed), Colors.green),
                  (pct(late), Colors.red),
                ]),
                child: const Center(
                  child: Text('Tasks',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _legend(color: Colors.grey, label: 'Not started', v: notStarted),
            _legend(color: Colors.blue, label: 'In progress', v: inProgress),
            _legend(color: Colors.green, label: 'Completed', v: completed),
            _legend(color: Colors.red, label: 'Late', v: late),
          ],
        ),
      ),
    );
  }

  Widget _recommendedCard(List<Task> rec) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommended next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (rec.isEmpty)
              const Text("No tasks for now 🎉")
            else
              ...rec.map((t) => TaskListTile(task: t, compact: true)),
          ],
        ),
      ),
    );
  }

  Widget _petMoodCard(PetMoodController petMood) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pet mood: ${petMood.currentMood.value}",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (petMood.logs.isEmpty)
                const Text("No pet mood logs yet 🦈")
              else
                ...petMood.logs.take(6).map((x) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        "${x.ts.toLocal().toString().substring(0, 16)} • ${x.mood} (${x.reason})",
                        style:
                            const TextStyle(color: Color(0xFF666666)),
                      ),
                    )),
            ],
          );
        }),
      ),
    );
  }

  Widget _userMoodCard() {
    final mc = Get.find<MoodController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final has = mc.history.isNotEmpty;
          final latest = has ? mc.history.first : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Mood',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (!has)
                const Text("No mood logged yet 🌱")
              else ...[
                Text("Latest: ${latest!.label}",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(latest.ts.toLocal().toString().substring(0, 16),
                    style: const TextStyle(color: Color(0xFF777777))),
                if (latest.notes != null && latest.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text("“${latest.notes}”",
                        style: const TextStyle(
                            fontStyle: FontStyle.italic)),
                  ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Get.toNamed('/mood_tracking'),
                  icon: const Icon(Icons.favorite),
                  label: Text(has ? 'Log again' : 'Log mood'),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  static Widget _legend(
      {required Color color, required String label, required int v}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$v'),
        ],
      ),
    );
  }
}

// Donut painter
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts);
  final List<(double, Color)> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * .38;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..color = Colors.grey.shade300;
    canvas.drawCircle(center, r, bg);

    double start = -90 * 3.14159 / 180.0;
    for (final (v, c) in parts) {
      if (v <= 0) continue;
      final sweep = v * 2 * 3.14159;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 24
        ..color = c;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: r), start, sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.parts != parts;
}

class InsightsCard extends StatelessWidget {
  const InsightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<InsightsController>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          if (c.loading.value) {
            return const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Analysis…'),
              subtitle:
                  Text('I am checking your tasks and generating insights.'),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Insights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (c.summary.value.isEmpty)
                TextButton.icon(
                  onPressed: c.refreshInsights,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Insights'),
                )
              else ...[
                Text(c.summary.value),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: c.refreshInsights,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Restart Analysis'),
                      /*),
                    OutlinedButton.icon(
                      onPressed: () => Get.toNamed('/graph'),
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Show graph'),*/
                    ),
                  ],
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}
