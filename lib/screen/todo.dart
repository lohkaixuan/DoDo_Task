import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/todoController.dart';
import '../controller/petController.dart';
import '../widget/task_item.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final titleCtrl = TextEditingController();
  int priority = 3;
  int importance = 3;
  String mode = 'study'; // study | personal | family

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
      appBar: AppBar(title: const Text('To-Do')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'New task'))),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: mode,
                  items: const [
                    DropdownMenuItem(value: 'study', child: Text('Study')),
                    DropdownMenuItem(value: 'personal', child: Text('Personal')),
                    DropdownMenuItem(value: 'family', child: Text('Family')),
                  ],
                  onChanged: (v) => setState(() => mode = v!),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: priority,
                  items: List.generate(5, (i) => DropdownMenuItem(value: i+1, child: Text('⭐ ${i+1}'))),
                  onChanged: (v) => setState(() => priority = v!),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: importance,
                  items: List.generate(5, (i) => DropdownMenuItem(value: i+1, child: Text('🔥 ${i+1}'))),
                  onChanged: (v) => setState(() => importance = v!),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final text = titleCtrl.text.trim();
                    if (text.isEmpty) return;
                    await todo.add(title: text, priority: priority, importance: importance, mode: mode);
                    titleCtrl.clear();
                    pet.onTaskCompleted(); // reward coin for adding? (optional)
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
                final subtitle = '⭐${t.priority}  🔥${t.importance}  • ${t.mode}';
                return TaskItem(
                  title: t.title,
                  completed: t.completed,
                  subtitle: subtitle,
                  onFocusTap: () => _openFocusSheet(context, t.id, t.title),
                  onToggle: () async {
                    final wasCompleted = t.completed;
                    await todo.toggle(t.id);
                    if (!wasCompleted && todo.tasks[index].completed) {
                      pet.onTaskCompleted();
                    }
                  },
                  onDelete: () => todo.remove(t.id),
                  onEdit: () => _openEditDialog(context, t.id),
                );
              },
            ),
          ),
          if (todo.focusedTaskId != null) _FocusBar(todo: todo),
        ],
      ),
    );
  }

  void _openFocusSheet(BuildContext context, String id, String title) {
    final todo = context.read<TodoController>();
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Focus: $title', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton(onPressed: () { todo.startFocus(id, minutes: 25); Navigator.pop(context); }, child: const Text('25m')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () { todo.startFocus(id, minutes: 45); Navigator.pop(context); }, child: const Text('45m')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () { todo.startFocus(id, minutes: 60); Navigator.pop(context); }, child: const Text('60m')),
          ]),
        ]),
      ),
    );
  }

  void _openEditDialog(BuildContext context, String id) {
    final todo = context.read<TodoController>();
    final t = todo.tasks.firstWhere((e) => e.id == id);
    final title = TextEditingController(text: t.title);
    var p = t.priority, im = t.importance, m = t.mode;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit task'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Priority'), const SizedBox(width: 8),
            DropdownButton<int>(
              value: p,
              items: List.generate(5, (i) => DropdownMenuItem(value: i+1, child: Text('${i+1}'))),
              onChanged: (v) => (p = v!),
            ),
            const SizedBox(width: 16),
            const Text('Importance'), const SizedBox(width: 8),
            DropdownButton<int>(
              value: im,
              items: List.generate(5, (i) => DropdownMenuItem(value: i+1, child: Text('${i+1}'))),
              onChanged: (v) => (im = v!),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Mode'), const SizedBox(width: 8),
            DropdownButton<String>(
              value: m,
              items: const [
                DropdownMenuItem(value: 'study', child: Text('Study')),
                DropdownMenuItem(value: 'personal', child: Text('Personal')),
                DropdownMenuItem(value: 'family', child: Text('Family')),
              ],
              onChanged: (v) => (m = v!),
            ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await todo.edit(id, t.copyWith(title: title.text.trim(), priority: p, importance: im, mode: m));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _FocusBar extends StatelessWidget {
  final TodoController todo;
  const _FocusBar({required this.todo, super.key});

  @override
  Widget build(BuildContext context) {
    final mins = (todo.focusRemainingSec ~/ 60).toString().padLeft(2, '0');
    final secs = (todo.focusRemainingSec % 60).toString().padLeft(2, '0');
    return Container(
      color: Colors.black12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const Icon(Icons.timer),
        const SizedBox(width: 8),
        Text('Focus ${todo.focusedTaskId ?? ''}  $mins:$secs'),
        const Spacer(),
        if (!todo.focusRunning) ElevatedButton(onPressed: todo.resumeFocus, child: const Text('Resume')),
        if (todo.focusRunning) ElevatedButton(onPressed: todo.pauseFocus, child: const Text('Pause')),
        const SizedBox(width: 8),
        TextButton(onPressed: todo.stopFocus, child: const Text('Stop')),
      ]),
    );
  }
}
