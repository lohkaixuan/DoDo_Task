import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/graphController.dart';

class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<GraphController>()
        ? Get.find<GraphController>()
        : Get.put(GraphController());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report 📈"),
        actions: [
          IconButton(
            onPressed: c.fetchDaily,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (c.points.isEmpty) {
          return const Center(child: Text("No data yet. Do some focus sessions 🦈"));
        }

        final maxV = c.points.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b);
        final avg = (c.points.map((e) => e.minutes).reduce((a, b) => a + b) / c.points.length).round();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // controls
            Row(
              children: [
                const Text("Range:", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                _rangeChip(c, 7),
                const SizedBox(width: 8),
                _rangeChip(c, 14),
                const SizedBox(width: 8),
                _rangeChip(c, 30),
              ],
            ),
            const SizedBox(height: 12),

            // summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _metric("Max", "$maxV min"),
                    _metric("Avg", "$avg min"),
                    _metric("Days", "${c.points.length}"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 260,
                  child: CustomPaint(
                    painter: _LineChartPainter(c.points),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // latest rows
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Latest focus minutes",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    ...c.points.reversed.take(8).map((p) {
                      final d = "${p.day.month.toString().padLeft(2, '0')}-${p.day.day.toString().padLeft(2, '0')}";
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text("$d  •  ${p.minutes} min"),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _rangeChip(GraphController c, int v) {
    return Obx(() => ChoiceChip(
          label: Text("$v days"),
          selected: c.days.value == v,
          onSelected: (_) => c.setDays(v),
        ));
  }

  Widget _metric(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<DailyFocusPoint> pts;
  _LineChartPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 24.0;
    final w = size.width;
    final h = size.height;

    // axes
    final axisPaint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..color = Colors.black12;

    // x axis
    canvas.drawLine(Offset(pad, h - pad), Offset(w - pad, h - pad), axisPaint);
    // y axis
    canvas.drawLine(Offset(pad, pad), Offset(pad, h - pad), axisPaint);

    if (pts.isEmpty) return;

    final maxV = pts.map((e) => e.minutes).fold<int>(1, (a, b) => a > b ? a : b);
    final n = pts.length;

    Offset toXY(int i, int v) {
      final x = pad + (n == 1 ? 0 : (i / (n - 1)) * (w - pad * 2));
      final yNorm = v / maxV;
      final y = (h - pad) - yNorm * (h - pad * 2);
      return Offset(x, y);
    }

    // line
    final linePaint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.blue;

    final path = Path();
    for (int i = 0; i < n; i++) {
      final o = toXY(i, pts[i].minutes);
      if (i == 0) path.moveTo(o.dx, o.dy);
      else path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, linePaint);

    // points
    final dotPaint = Paint()..color = Colors.blue;
    for (int i = 0; i < n; i++) {
      final o = toXY(i, pts[i].minutes);
      canvas.drawCircle(o, 4, dotPaint);
    }

    // min/max labels (simple)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawText(String t, Offset o) {
      textPainter.text = TextSpan(
        text: t,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(canvas, o);
    }

    drawText("0", Offset(4, h - pad - 8));
    drawText("$maxV", Offset(4, pad - 6));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.pts != pts;
}
