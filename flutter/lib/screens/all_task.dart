import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:v3/bottomnav/bottomnav.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/models/task.dart';
import 'package:v3/widgets/task_list_tile.dart';

class AllTasks extends StatefulWidget {
  const AllTasks({super.key});
  @override
  State<AllTasks> createState() => _AllTasksState();
}

class _AllTasksState extends State<AllTasks> {
  int _tab = 0; // 0=list, 1=calendar
  String? _category; // null = all
  PriorityLevel? _priority; // null = all
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TaskController>();
    final cats = <String>{}
      ..addAll(tc.tasks.map((t) => t.category ?? '').where((s) => s.isNotEmpty));

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Toggle List / Calendar
          _ModeSwitch(tab: _tab, onChanged: (v) => setState(() => _tab = v)),
          const SizedBox(height: 8),

          // Filters row (works for both tabs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ...cats.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<PriorityLevel>(
                    value: _priority,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: PriorityLevel.low, child: Text('Low')),
                      DropdownMenuItem(value: PriorityLevel.medium, child: Text('Medium')),
                      DropdownMenuItem(value: PriorityLevel.high, child: Text('High')),
                      DropdownMenuItem(value: PriorityLevel.urgent, child: Text('Urgent')),
                    ],
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Obx(() {
              final all = tc.tasks.toList();

              // Apply filters
              final filtered = all.where((t) {
                final cat = _category;
                final pri = _priority;
                final okCat = (cat == null) || ((t.category ?? '') == cat);
                final okPri = (pri == null) || (t.priority == pri);
                return okCat && okPri;
              }).toList();

              if (_tab == 0) {
                // LIST
                // sort by due/start then title
                filtered.sort((a, b) {
                  DateTime ad = a.dueDateTime ?? a.dueDate ?? a.startDate ?? a.createdAt;
                  DateTime bd = b.dueDateTime ?? b.dueDate ?? b.startDate ?? b.createdAt;
                  final c = ad.compareTo(bd);
                  return c != 0 ? c : a.title.compareTo(b.title);
                });

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, kBottomReserve),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => TaskListTile(task: filtered[i]),
                );
              } else {
                // CALENDAR (lite)
                return _CalendarLite(
                  selected: _selected,
                  onSelect: (d) => setState(() => _selected = d),
                  tasksForDay: (d) => filtered.where((t) {
                    final isSingle = t.type == TaskType.singleDay;
                    if (isSingle && t.dueDateTime != null) {
                      final dd = t.dueDateTime!;
                      return dd.year == d.year && dd.month == d.month && dd.day == d.day;
                    }
                    if (!isSingle && t.startDate != null && t.dueDate != null) {
                      final sd = DateTime(d.year, d.month, d.day);
                      final start = DateTime(t.startDate!.year, t.startDate!.month, t.startDate!.day);
                      final end = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
                      return !sd.isBefore(start) && !sd.isAfter(end);
                    }
                    return false;
                  }).toList(),
                );
              }
            }),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.tab, required this.onChanged});
  final int tab;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('List')),
          ButtonSegment(value: 1, label: Text('Calendar (lite)')),
        ],
        selected: {tab},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

/// Simple month grid with counts and a bottom sheet for the day’s tasks.
class _CalendarLite extends StatefulWidget {
  const _CalendarLite({
    required this.selected,
    required this.onSelect,
    required this.tasksForDay,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final List<Task> Function(DateTime day) tasksForDay;

  @override
  State<_CalendarLite> createState() => _CalendarLiteState();
}

class _CalendarLiteState extends State<_CalendarLite> {
  late DateTime _cursor; // first day of month being shown

  @override
  void initState() {
    super.initState();
    _cursor = DateTime(widget.selected.year, widget.selected.month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final first = _cursor;
    final firstWeekday = first.weekday; // Mon=1 … Sun=7
    final daysInMonth = DateUtils.getDaysInMonth(first.year, first.month);
    final totalCells = ((firstWeekday - 1) + daysInMonth);
    final rows = (totalCells / 7.0).ceil();

    final fmt = DateFormat('MMMM yyyy');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Center(
                  child: Text(fmt.format(_cursor),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, kBottomReserve),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: rows * 7,
            itemBuilder: (_, i) {
              final dayNum = i - (firstWeekday - 1) + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final d = DateTime(first.year, first.month, dayNum);
              final items = widget.tasksForDay(d);
              final isSel = d.year == widget.selected.year &&
                  d.month == widget.selected.month &&
                  d.day == widget.selected.day;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  widget.onSelect(d);
                  if (!mounted) return;
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _DaySheet(date: d, tasks: items),
                  );
                  setState(() {}); // refresh counts if changed
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                    ),
                    color: isSel ? Theme.of(context).colorScheme.primary.withOpacity(.08) : null,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 8, top: 6,
                        child: Text('$dayNum', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (items.isNotEmpty)
                        Positioned(
                          right: 6, top: 6,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text('${items.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.date, required this.tasks});
  final DateTime date;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, MMM d');
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12, right: 12, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fmt.format(date), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tasks.length,
                itemBuilder: (_, i) => TaskListTile(task: tasks[i], compact: true),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
