import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/insightsController.dart';
import 'package:v3/controller/petController.dart';
import 'package:v3/controller/petMoodController.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/models/task.dart';
import 'package:v3/widgets/coin_badge.dart';
import 'package:v3/widgets/pad.dart';
import 'package:v3/widgets/pet_header.dart';
import 'package:v3/widgets/task_list_tile.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TaskController>();
    final pet = Get.find<PetController>();
    final petMood = Get.find()<PetMoodController>()
    ? Get.find<PetMoodController>()
    : Get.put(PetMoodController());

    // ✅ 2. 改成 Scaffold 结构
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        // ✅ 3. 金币显示在这里！
        actions: const [
          CoinBadge(),
          SizedBox(width: 16),
        ],
      ),
      body: Obx(() {
        final all = tc.tasks;
        final now = DateTime.now();

        final notStarted = all
            .where((t) => t.computeStatus(now) == TaskStatus.notStarted)
            .length;
        final inProgress = all
            .where((t) => t.computeStatus(now) == TaskStatus.inProgress)
            .length;
        final completed =
            all.where((t) => t.status == TaskStatus.completed).length;
        final late =
            all.where((t) => t.computeStatus(now) == TaskStatus.late).length;
        final total =
            (notStarted + inProgress + completed + late).clamp(1, 1 << 30);

        double pct(int v) => v / total;

        final rec = tc.recommended(max: 5);

        return ListView(
          padding: padAll(context, h: 16, v: 16),
          children: [
            // Pet header
            const PetHeader(),

            // Donut Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Task Stats',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: CustomPaint(
                        painter: _DonutPainter([
                          (pct(notStarted), Colors.grey.shade400),
                          (pct(inProgress), Colors.blue),
                          (pct(completed), Colors.green),
                          (pct(late), Colors.red),
                        ]),
                        child: const Center(
                          child: Text('Tasks',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _legend(
                        color: Colors.grey.shade400,
                        label: 'Not started',
                        v: notStarted),
                    _legend(
                        color: Colors.blue,
                        label: 'In progress',
                        v: inProgress),
                    _legend(
                        color: Colors.green, label: 'Completed', v: completed),
                    _legend(color: Colors.red, label: 'Late', v: late),
                  ],
                ),
              ),
            ),

            // AI Insights
            const SizedBox(
              height: 12,
            ),
            const InsightsCard(),

            // 在 ListView children 里（InsightsCard 后面）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pet mood: ${petMood.currentMood.value}",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (petMood.logs.isEmpty)
                        const Text("No pet mood logs yet 🦈")
                      else
                        ...petMood.logs.take(8).map((x) => Padding(
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
            ),

            // Recommended
            const SizedBox(height: 12),
            if (rec.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommended next',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ...rec.map((t) => TaskListTile(task: t, compact: true)),
                    ],
                  ),
                ),
              ),

            // ✅ 4. 底部留白，防止被底部的 Floating Pet Head 挡住
            const SizedBox(height: 100),
          ],
        );
      }),
    );
  }

  Widget _legend(
      {required Color color, required String label, required int v}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$v'),
        ],
      ),
    );
  }
}

// 👇 下面的类原封不动，负责画图和 AI 总结
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
    final c = Get.find<InsightsController>(); // ✅ only find

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
              const Text('AI Insights',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Get.toNamed('/graph');
                      },
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Show graph'),
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
