import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/todoController.dart';
import '../controller/petController.dart';
import '../widget/task_item.dart';
import '../widget/pet_overlay_launcher.dart';
import '../widget/pet_overlay/overlay_service.dart' as overlay;

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TodoController>().fetch());
  }

  @override
  Widget build(BuildContext context) {
    final todo = context.watch<TodoController>();
    final pet = context.read<PetController>();

    return Scaffold(
      appBar: AppBar(title: const Text('To-Do'), actions: const [PetOverlayLauncher()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: controller, decoration: const InputDecoration(labelText: 'New task'))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final resp = await todo.add(controller.text.trim());
                    if (resp.status == 'ok') {
                      controller.clear();
                      pet.onTaskCompleted();
                      try { await overlay.triggerReaction('celebrate'); } catch (_) {}
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.message)));
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: todo.tasks.length,
              itemBuilder: (context, index) {
                final t = todo.tasks[index];
                return TaskItem(
                  title: t['title']?.toString() ?? '',
                  completed: t['completed'] == true,
                  onChanged: (v) async {
                    final wasCompleted = t['completed'] == true;
                    final resp = await todo.toggle(t['id'].toString());
                    if (!wasCompleted && (v ?? false) && resp.status == 'ok') {
                      pet.onTaskCompleted();
                      try { await overlay.triggerReaction('celebrate'); } catch (_) {}
                    }
                    if (resp.status != 'ok') {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.message)));
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
