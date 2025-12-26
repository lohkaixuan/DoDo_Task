// lib/screens/add_update_task.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:v3/controller/taskController.dart';
import 'package:v3/models/task.dart';

class AddUpdateTaskSheet extends StatefulWidget {
  const AddUpdateTaskSheet({
    super.key,
    required this.controller,
    this.initial,
  });

  final TaskController controller;
  final Task? initial;

  @override
  State<AddUpdateTaskSheet> createState() => _AddUpdateTaskSheetState();
}

class _AddUpdateTaskSheetState extends State<AddUpdateTaskSheet> {
  // basic
  final _title = TextEditingController();
  final _category = TextEditingController();
  TaskType _type = TaskType.singleDay;

  // scheduling
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  DateTime? _startDate;
  DateTime? _endDate;

  // NEW: planning
  PriorityLevel _priority = PriorityLevel.medium;
  bool _important = true;

  // estimate HH:MM
  final _estHours = TextEditingController();
  final _estMins = TextEditingController();

  // Daily reminder toggle + time (uses NotificationPrefs.dailyHour/minute)
  bool _dailyReminder = false;
  TimeOfDay _dailyAt = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _title.text = t.title;
      _category.text = t.category ?? '';
      _type = t.type;

      // scheduling
      if (t.type == TaskType.singleDay) {
        if (t.dueDateTime != null) {
          _dueDate = DateTime(
              t.dueDateTime!.year, t.dueDateTime!.month, t.dueDateTime!.day);
          _dueTime = TimeOfDay(
              hour: t.dueDateTime!.hour, minute: t.dueDateTime!.minute);
        }
      } else {
        _startDate = t.startDate;
        _endDate = t.dueDate;
      }

      // planning
      _priority = t.priority;
      _important = t.important;

      final est = t.estimatedMinutes ?? 0;
      _estHours.text = (est ~/ 60).toString();
      _estMins.text = (est % 60).toString();

      // daily reminder
      if (t.notify.repeatWhenToday == RepeatGranularity.day) {
        _dailyReminder = true;
        final h = t.notify.dailyHour ?? 9;
        final m = t.notify.dailyMinute ?? 0;
        _dailyAt = TimeOfDay(hour: h, minute: m);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _estHours.dispose();
    _estMins.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding:
            EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(widget.initial == null ? 'Add Task' : 'Update Task',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              TextField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _category,
                decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              // single vs ranged
              SegmentedButton<TaskType>(
                segments: const [
                  ButtonSegment(
                      value: TaskType.singleDay, label: Text('Single/Due')),
                  ButtonSegment(
                      value: TaskType.ranged, label: Text('Start → Due')),
                ],
                selected: <TaskType>{_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),

              if (_type == TaskType.singleDay)
                _singleFields(context)
              else
                _rangeFields(context),
              const SizedBox(height: 12),

              // NEW: Priority + Important
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<PriorityLevel>(
                    value: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(
                          value: PriorityLevel.urgent, child: Text('Urgent')),
                      DropdownMenuItem(
                          value: PriorityLevel.high, child: Text('High')),
                      DropdownMenuItem(
                          value: PriorityLevel.medium, child: Text('Medium')),
                      DropdownMenuItem(
                          value: PriorityLevel.low, child: Text('Low')),
                    ],
                    onChanged: (v) =>
                        setState(() => _priority = v ?? PriorityLevel.medium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Important'),
                    value: _important,
                    onChanged: (v) => setState(() => _important = v),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Estimate fields
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _estHours,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Hours', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _estMins,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Minutes', border: OutlineInputBorder()),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Daily reminder toggle + time
              _dailyReminderTile(context),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(widget.initial == null ? 'Create' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- UI blocks ----

  Widget _singleFields(BuildContext context) {
    final fmt = DateFormat('MMM d');
    return Row(children: [
      Expanded(
        child: ListTile(
          title: const Text('Due date'),
          subtitle: Text(_dueDate == null ? '—' : fmt.format(_dueDate!)),
          trailing: const Icon(Icons.event),
          onTap: () async {
            final now = DateTime.now();
            final res = await showDatePicker(
              context: context,
              initialDate: _dueDate ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 5),
            );
            if (res != null) setState(() => _dueDate = res);
          },
        ),
      ),
      Expanded(
        child: ListTile(
          title: const Text('Due time'),
          subtitle: Text(_dueTime == null ? '—' : _dueTime!.format(context)),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            final res = await showTimePicker(
              context: context,
              initialTime: _dueTime ?? TimeOfDay.now(),
            );
            if (res != null) setState(() => _dueTime = res);
          },
        ),
      ),
    ]);
  }

  Widget _rangeFields(BuildContext context) {
    final fmt = DateFormat('MMM d');
    return Row(children: [
      Expanded(
        child: ListTile(
          title: const Text('Start date'),
          subtitle: Text(_startDate == null ? '—' : fmt.format(_startDate!)),
          trailing: const Icon(Icons.event_available),
          onTap: () async {
            final now = DateTime.now();
            final res = await showDatePicker(
              context: context,
              initialDate: _startDate ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 5),
            );
            if (res != null) setState(() => _startDate = res);
          },
        ),
      ),
      Expanded(
        child: ListTile(
          title: const Text('Due date'),
          subtitle: Text(_endDate == null ? '—' : fmt.format(_endDate!)),
          trailing: const Icon(Icons.event_note),
          onTap: () async {
            final now = DateTime.now();
            final res = await showDatePicker(
              context: context,
              initialDate: _endDate ?? _startDate ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 5),
            );
            if (res != null) setState(() => _endDate = res);
          },
        ),
      ),
    ]);
  }

  Widget _dailyReminderTile(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Daily reminder'),
      subtitle: Text(_dailyReminder
          ? 'Every day at ${_two(_dailyAt.hour)}:${_two(_dailyAt.minute)}'
          : 'Send me a reminder every day'),
      trailing: Switch(
        value: _dailyReminder,
        onChanged: (v) async {
          if (v) {
            final t = await showTimePicker(
              context: context,
              initialTime: _dailyAt,
            );
            if (t != null) _dailyAt = t;
          }
          setState(() => _dailyReminder = v);
        },
      ),
      onTap: !_dailyReminder
          ? null
          : () async {
              final t =
                  await showTimePicker(context: context, initialTime: _dailyAt);
              if (t != null) setState(() => _dailyAt = t);
            },
    );
  }

  // ---- save ----

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      Get.snackbar('Missing title', 'Please enter a task title');
      return;
    }

    DateTime? dueDT;
    DateTime? startD;
    DateTime? endD;

    if (_type == TaskType.singleDay) {
      if (_dueDate == null || _dueTime == null) {
        Get.snackbar('Missing time', 'Select due date & time');
        return;
      }
      dueDT = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day,
          _dueTime!.hour, _dueTime!.minute);
    } else {
      if (_startDate == null || _endDate == null) {
        Get.snackbar('Missing dates', 'Select start & due dates');
        return;
      }
      startD = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      endD = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    }

    final int estMinutes = (_parseInt(_estHours) * 60) + _parseInt(_estMins);
    final notif = _buildNotificationPrefs();

    if (widget.initial == null) {
      final t = Task(
        id: UniqueKey().toString(),
        title: title,
        type: _type,
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        dueDateTime: dueDT,
        startDate: startD,
        dueDate: endD,
        priority: _priority,
        important: _important,
        estimatedMinutes: estMinutes > 0 ? estMinutes : null,
        notify: notif,
      );
      widget.controller.addTask(t);
    } else {
      final t = widget.initial!.copyWith(
        title: title,
        type: _type,
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        dueDateTime: dueDT,
        startDate: startD,
        dueDate: endD,
        priority: _priority,
        important: _important,
        estimatedMinutes: estMinutes > 0 ? estMinutes : null,
        notify: notif,
      );
      widget.controller.updateTask(t);
    }
    Get.back();
  }

  NotificationPrefs _buildNotificationPrefs() {
    // Always start from a non-null base
    final base = widget.initial?.notify ?? const NotificationPrefs();

    if (_dailyReminder) {
      // store the chosen time too (works if your model has dailyHour/dailyMinute)
      return base.copyWith(
        repeatWhenToday: RepeatGranularity.day,
        repeatInterval: 1,
        dailyHour: _dailyAt.hour, // keep if your NotificationPrefs has these
        dailyMinute:
            _dailyAt.minute, // fields; otherwise just remove these 2 lines
      );
    }

    // Toggle OFF: keep other prefs but disable repeating "today" nudges
    return base.copyWith(
      repeatWhenToday: RepeatGranularity.none,
    );
  }

  // helpers
  int _parseInt(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  String _two(int v) => v.toString().padLeft(2, '0');
}
