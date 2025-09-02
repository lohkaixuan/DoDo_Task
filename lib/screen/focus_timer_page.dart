import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/petController.dart';
import '../controller/taskController.dart';
import '../models/task.dart';

class FocusTimerPage extends StatefulWidget {
  final Task task;
  final String userId;
  const FocusTimerPage({super.key, required this.task, required this.userId, required taskTitle, required taskId});

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    final tasks = context.read<TaskController>();
    tasks.startFocus(widget.task, widget.userId);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      // Optional: send focus_tick event every N seconds with /wellbeing/events
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int s) => "${(s ~/ 60).toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}";

  String _assetFor(String action) {
    switch (action) {
      case 'focus': return 'assets/pet/focus.gif';
      case 'celebrate': return 'assets/pet/celebrate.gif';
      case 'sleep': return 'assets/pet/sleep.gif';
      default: return 'assets/pet/idle.gif';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetController>();
    final asset = _assetFor(pet.currentAction as String);

    return Scaffold(
      appBar: AppBar(title: Text('Focusing: ${widget.task.title}')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_fmt(_seconds), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Image.asset(asset, height: 160, fit: BoxFit.contain),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  context.read<TaskController>().stopFocus();
                  Navigator.pop(context);
                },
                child: const Text('Stop'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await context.read<TaskController>().completeActive(widget.userId);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Complete'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
