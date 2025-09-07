import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/InsightsController.dart';

import '../widgets/pad.dart';
import '../widgets/pet_header.dart';
import '../widgets/task_list_tile.dart';
import '../controller/taskController.dart';
import '../controller/petController.dart';
import '../models/task.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TaskController>();
    final pet = Get.find<PetController>();

    return SafeArea(
      child: Obx(() {
        final all = tc.tasks;
        final now = DateTime.now();

        final notStarted = all.where((t) => t.computeStatus(now) == TaskStatus.notStarted).length;
        final inProgress = all.where((t) => t.computeStatus(now) == TaskStatus.inProgress).length;
        final completed  = all.where((t) => t.status == TaskStatus.completed).length;
        final late       = all.where((t) => t.computeStatus(now) == TaskStatus.late).length;
        final total      = (notStarted + inProgress + completed + late).clamp(1, 1<<30);

        double pct(int v) => v / total;

        // top recommendations (auto updates after complete/edit)
        final rec = tc.recommended(max: 5);

        return ListView(
          padding: padAll(context, h: 16, v: 16),
          children: [
            // Pet header (uses sprite from PetController)
            PetHeader(imageOverride: pet.currentSprite),

            // Donut
            Card(
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
                          (pct(notStarted), Colors.grey.shade400),
                          (pct(inProgress), Colors.blue),
                          (pct(completed),  Colors.green),
                          (pct(late),       Colors.red),
                        ]),
                        child: const Center(
                          child: Text('Tasks',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _legend(color: Colors.grey.shade400, label: 'Not started', v: notStarted),
                    _legend(color: Colors.blue,           label: 'In progress', v: inProgress),
                    _legend(color: Colors.green,          label: 'Completed',   v: completed),
                    _legend(color: Colors.red,            label: 'Late',        v: late),
                  ],
                ),
              ),
            ),

            // AI Insights
            const SizedBox(height: 12,),
            const InsightsCard(),

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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ...rec.map((t) => TaskListTile(task: t, compact: true)),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _legend({required Color color, required String label, required int v}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$v'),
        ],
      ),
    );
  }
}

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
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false, p);
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
    final c = Get.put(InsightsController(),permanent: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          if (c.loading.value) {
            return const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('analysis…'),
              subtitle: Text('I am checking your tasks and generating insights.'),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Insights',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if ((c.summary.value).isEmpty)
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
                    if (c.metrics != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          // 你可以跳到一个详情页，展示 charts
                          Get.snackbar('Metrics', '可在下一版展示图表/明细',
                              snackPosition: SnackPosition.BOTTOM);
                        },
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('show graph(next version)'),
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