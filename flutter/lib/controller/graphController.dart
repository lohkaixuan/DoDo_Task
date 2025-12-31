import 'package:get/get.dart';
import '../api/dioclient.dart';

class DailyFocusPoint {
  final DateTime day;
  final int minutes;

  DailyFocusPoint({required this.day, required this.minutes});

  factory DailyFocusPoint.fromJson(Map<String, dynamic> j) {
    final dateStr = (j['date'] ?? '').toString(); // "YYYY-MM-DD"
    final day = DateTime.tryParse(dateStr) ?? DateTime.now();
    final mins = (j['total_focus_minutes'] ?? 0);
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

      points.assignAll(parsed);
    } finally {
      loading.value = false;
    }
  }

  void setDays(int v) {
    days.value = v;
    fetchDaily();
  }
}
