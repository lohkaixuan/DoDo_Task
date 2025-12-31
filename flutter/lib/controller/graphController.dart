import 'package:get/get.dart';
import '../api/dioclient.dart';

class DailyFocusPoint {
  final DateTime day;
  final int minutes;

  DailyFocusPoint({required this.day, required this.minutes});

  factory DailyFocusPoint.fromJson(Map<String, dynamic> j) {
    final dateStr = (j['date'] ?? '').toString(); // "YYYY-MM-DD"
    final day = DateTime.tryParse(dateStr) ?? DateTime.now();
    final mins = j['total_focus_minutes'] ?? 0;
    return DailyFocusPoint(
      day: DateTime(day.year, day.month, day.day),
      minutes: (mins is num) ? mins.toInt() : 0,
    );
  }
}

class GraphController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();

  final loading = false.obs;
  final days = 14.obs;

  final points = <DailyFocusPoint>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchDaily();
  }

  Future<void> fetchDaily() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final res = await _dio.dio.get('/wellbeing/stats/daily?days=${days.value}');
      final root = (res.data is Map) ? Map<String, dynamic>.from(res.data) : {};
      final list = (root['data'] as List? ?? []).cast<dynamic>();

      final parsed = list
          .map((e) => DailyFocusPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // ✅ fill missing days with 0
      points.assignAll(_fillMissingDays(parsed, days.value));
    } catch (_) {
      // ✅ even if API fails, show empty trend of 0s (UI still works)
      points.assignAll(_fillMissingDays([], days.value));
    } finally {
      loading.value = false;
    }
  }

  void setDays(int v) {
    days.value = v;
    fetchDaily();
  }

  List<DailyFocusPoint> _fillMissingDays(List<DailyFocusPoint> input, int nDays) {
    final map = <String, DailyFocusPoint>{};
    for (final p in input) {
      final key = _key(p.day);
      map[key] = p;
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: nDays - 1));

    final out = <DailyFocusPoint>[];
    for (int i = 0; i < nDays; i++) {
      final d = start.add(Duration(days: i));
      final key = _key(d);
      out.add(map[key] ?? DailyFocusPoint(day: d, minutes: 0));
    }
    return out;
  }

  String _key(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}
