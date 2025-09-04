import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controller/taskController.dart';
import '../models/task.dart';

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
  final _title = TextEditingController();
  final _category = TextEditingController();

  // type & dates
  TaskType _type = TaskType.singleDay;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  DateTime? _startDate;
  DateTime? _endDate;

  // NEW: planning fields
  PriorityLevel _priority = PriorityLevel.medium;
  bool _important = true;
  final _estHours = TextEditingController();
  final _estMins = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _title.text = t.title;
      _category.text = t.category ?? '';
      _type = t.type;

      if (t.type == TaskType.singleDay) {
        if (t.dueDateTime != null) {
          _dueDate = DateTime(
              t.dueDateTime!.year, t.dueDateTime!.month, t.dueDateTime!.day);
          _dueTime =
              TimeOfDay(hour: t.dueDateTime!.hour, minute: t.dueDateTime!.minute);
        }
      } else {
        _startDate = t.startDate;
        _endDate = t.dueDate;
      }

      _priority = t.priority;
      _important = t.important;
      final est = t.estimatedMinutes ?? 0;
      _estHours.text = (est ~/ 60).toString();
      _estMins.text = (est % 60).toString();
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
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                widget.initial == null ? 'Add Task' : 'Update Task',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Title
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Category
              TextField(
                controller: _category,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Single vs ranged
              SegmentedButton<TaskType>(
                segments: const [
                  ButtonSegment(
                    value: TaskType.singleDay,
                    label: Text('Single/Due'),
                  ),
                ButtonSegment(
                    value: TaskType.ranged,
                    label: Text('Start → Due'),
                  ),
                ],
                selected: <TaskType>{_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),

              // Date fields
              if (_type == TaskType.singleDay)
                _singleFields(context)
              else
                _rangeFields(context),

              const SizedBox(height: 12),

              // Priority
              DropdownButtonFormField<PriorityLevel>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(
                      value: PriorityLevel.urgent, child: Text('Urgent')),
                  DropdownMenuItem(
                      value: PriorityLevel.high, child: Text('High')),
                  DropdownMenuItem(
                      value: PriorityLevel.medium, child: Text('Medium')),
                  DropdownMenuItem(value: PriorityLevel.low, child: Text('Low')),
                ],
                onChanged: (v) =>
                    setState(() => _priority = v ?? PriorityLevel.medium),
              ),
              const SizedBox(height: 8),

              // Important?
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Important'),
                value: _important,
                onChanged: (v) => setState(() => _important = v),
              ),
              const SizedBox(height: 8),

              // Estimate HH:MM
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _estHours,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Hours',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _estMins,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Save
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

  Widget _singleFields(BuildContext context) {
    final fmt = DateFormat('MMM d');
    return Row(
      children: [
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
      ],
    );
  }

  Widget _rangeFields(BuildContext context) {
    final fmt = DateFormat('MMM d');
    return Row(
      children: [
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
      ],
    );
  }

  int _parseInt(TextEditingController c) =>
      int.tryParse(c.text.trim()) ?? 0;

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

    final estTotal = (_parseInt(_estHours) * 60) + _parseInt(_estMins);
    final category =
        _category.text.trim().isEmpty ? null : _category.text.trim();

    // Build final task (create or update)
    final base = (widget.initial ??
            Task(
              id: UniqueKey().toString(),
              title: title,
              type: _type,
            ))
        .copyWith(
      title: title,
      type: _type,
      category: category,
      dueDateTime: dueDT,
      startDate: startD,
      dueDate: endD,
      priority: _priority,
      important: _important,
      estimatedMinutes: estTotal > 0 ? estTotal : null,
    );

    if (widget.initial == null) {
      widget.controller.addTask(base);
    } else {
      widget.controller.updateTask(base);
    }
    Get.back();
  }
}
