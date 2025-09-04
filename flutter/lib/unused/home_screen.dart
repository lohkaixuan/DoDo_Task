// // lib/screens/home_page.dart  (or wherever your HomePage lives)

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// import '../models/task.dart';
// import '../controller/taskController.dart';          // ⬅️ GetX controller
// import '../widgets/pet_chat_head.dart';
// import '../widgets/pet_header.dart';
// import '../screens/focus_timer_screen.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   @override
//   Widget build(BuildContext context) {

//     final modes = TaskMode.values;

//     return DefaultTabController(
//       length: modes.length,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('DoDO Task'),
//           actions: const [SizedBox(width: 8), OverlayTogglePill(), SizedBox(width: 8)],
//           bottom: PreferredSize(
//             preferredSize: const Size.fromHeight(48),
//             child: Align(
//               alignment: Alignment.centerLeft,
//               child: TabBar(
//                 padding: EdgeInsets.zero,    
//                 isScrollable: true,
//                 labelPadding: const EdgeInsets.symmetric(horizontal: 16),
//                 tabs: [for (final m in modes) Tab(text: m.label)],
//               ),
//             ),
//           ),
//         ),
//         floatingActionButton: FloatingActionButton(
//           onPressed: () => showModalBottomSheet(
//             context: context,
//             isScrollControlled: true,
//             builder: (_) => const TaskFormSheet(),
//           ),
//           child: const Icon(Icons.add),
//         ),
//         body: Stack(
//             fit: StackFit.expand, // important so the stack is full screen
//             children: [
//               Column(
//                 children: [
//                   const PetHeader(),
//                   Expanded(
//                     child: TabBarView(
//                       children: [
//                         for (final m in modes) TaskListByMode(mode: m)
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const PetChatHead(),
//             ]),
//       ),
//     );
//   }
// }

// /// One pill that toggles the floating overlay ON/OFF and shows state (OPEN/CLOSE).
// class OverlayTogglePill extends StatefulWidget {
//   const OverlayTogglePill({super.key});
//   @override
//   State<OverlayTogglePill> createState() => _OverlayTogglePillState();
// }

// class _OverlayTogglePillState extends State<OverlayTogglePill> {
//   bool _active = false;
//   bool _checking = true;

//   @override
//   void initState() {
//     super.initState();
//     _refresh();
//   }

//   Future<void> _refresh() async {
//     final active = await FlutterOverlayWindow.isActive();
//     if (!mounted) return;
//     setState(() {
//       _active = active;
//       _checking = false;
//     });
//   }

//   Future<void> _toggle() async {
//     if (_active) {
//       if (await FlutterOverlayWindow.isActive()) {
//         await FlutterOverlayWindow.closeOverlay();
//       }
//       if (!mounted) return;
//       setState(() => _active = false);
//       return;
//     }

//     var granted = await FlutterOverlayWindow.isPermissionGranted();
//     if (!granted) {
//       await FlutterOverlayWindow.requestPermission();
//       granted = await FlutterOverlayWindow.isPermissionGranted();
//     }
//     if (!granted) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('Overlay permission denied')));
//       return;
//     }

//     await FlutterOverlayWindow.showOverlay(
//       height: 180,
//       width: 180,
//       enableDrag: true,
//       alignment: OverlayAlignment.centerRight,
//       flag: OverlayFlag.defaultFlag,
//       visibility: NotificationVisibility.visibilityPublic,
//       overlayTitle: 'Overlay',
//       overlayContent: 'overlayMain', // must match @pragma entry point
//     );

//     if (!mounted) return;
//     setState(() => _active = true);
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_checking) {
//       return const Padding(
//         padding: EdgeInsets.only(right: 12),
//         child: SizedBox(
//           width: 64,
//           height: 32,
//           child: Center(
//             child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
//           ),
//         ),
//       );
//     }

//     final isOpen = _active;
//     final bg = isOpen ? const Color(0xFF6CC04A) : const Color(0xFFE74C3C);
//     final label = isOpen ? 'OVERLAY OPEN' : 'OVERLAY CLOSE';

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
//       child: InkWell(
//         onTap: _toggle,
//         borderRadius: BorderRadius.circular(22),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 180),
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//           decoration: BoxDecoration(
//             color: bg,
//             borderRadius: BorderRadius.circular(22),
//             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))],
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
//               const SizedBox(width: 8),
//               Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Reusable list widget that shows tasks for a given mode, grouped by Eisenhower.
// class TaskListByMode extends StatelessWidget {
//   final TaskMode mode;
//   const TaskListByMode({super.key, required this.mode});

//   @override
//   Widget build(BuildContext context) {
//     final taskC = Get.find<TaskController>();
//     final now = DateTime.now();

//     return Obx(() {
//       final items = taskC.active.where((t) => t.mode == mode).toList();
//       final groups = _groupByEisenhower(items, now);
//       final completed = taskC.done.where((t) => t.mode == mode).toList()
//         ..sort((a, b) {
//           final ad = a.completedAt ?? a.createdAt;
//           final bd = b.completedAt ?? b.createdAt;
//           return bd.compareTo(ad);
//         });

//       return ListView(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
//         children: [
//           for (final g in Eisenhower.values)
//             TaskSection(title: g.title, tasks: groups[g] ?? const []),
//           if (completed.isNotEmpty) CompletedSection(title: 'Completed', tasks: completed),
//           const SizedBox(height: 60),
//         ],
//       );
//     });
//   }
// }

// class TaskSection extends StatelessWidget {
//   final String title;
//   final List<Task> tasks;
//   const TaskSection({super.key, required this.title, required this.tasks});

//   @override
//   Widget build(BuildContext context) {
//     if (tasks.isEmpty) return const SizedBox.shrink();
//     final taskC = Get.find<TaskController>();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 12),
//         Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
//         const SizedBox(height: 8),
//         ...tasks.map(
//           (t) => Dismissible(
//             key: ValueKey(t.id),
//             direction: DismissDirection.horizontal,
//             background: _swipeBg(alignRight: false),
//             secondaryBackground: _swipeBg(alignRight: true),
//             confirmDismiss: (dir) async {
//               return await showDialog<bool>(
//                     context: context,
//                     builder: (ctx) => AlertDialog(
//                       title: const Text('Delete task?'),
//                       content: Text('Remove "${t.title}"?'),
//                       actions: [
//                         TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
//                         FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
//                       ],
//                     ),
//                   ) ??
//                   false;
//             },
//             onDismissed: (_) => taskC.remove(t),
//             child: TaskTile(task: t),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class TaskTile extends StatelessWidget {
//   final Task task;
//   const TaskTile({super.key, required this.task});

//   @override
//   Widget build(BuildContext context) {
//     final taskC = Get.find<TaskController>();

//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       child: ListTile(
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         onTap: () => _handleOpenTimer(context, task),
//         leading: Checkbox(
//           value: task.completed,
//           onChanged: (_) => taskC.toggle(task),
//         ),
//         title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
//         subtitle: _TaskMetaChips(task: task),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('P${task.priority}'),
//             const SizedBox(width: 8),
//             IconButton(
//               tooltip: 'Edit',
//               icon: const Icon(Icons.edit),
//               onPressed: () => _openEditSheet(context, task),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _handleOpenTimer(BuildContext context, Task t) async {
//     final st = Get.find<TaskController>();
//     // Optional: respect an existing running timer if your controller exposes it
//     if (st.timerActive.value && st.activeTimerTaskId.value != t.id) {
//       final running = st.all.firstWhere(
//         (x) => x.id == st.activeTimerTaskId.value,
//         orElse: () => t,
//       );
//       final go = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           title: const Text('A timer is already running'),
//           content: Text(
//             'You are focusing on "${running.title}". '
//             'Finish or pause it before starting another. Jump to it now?',
//           ),
//           actions: [
//             TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
//             FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Go to timer')),
//           ],
//         ),
//       );
//       if (go == true && context.mounted) {
//         Navigator.push(context, MaterialPageRoute(builder: (_) => FocusTimerScreen(task: running)));
//       }
//       return;
//     }
//     if (!context.mounted) return;
//     Navigator.push(context, MaterialPageRoute(builder: (_) => FocusTimerScreen(task: t)));
//   }
// }

// class CompletedSection extends StatelessWidget {
//   final String title;
//   final List<Task> tasks;
//   const CompletedSection({super.key, required this.title, required this.tasks});

//   @override
//   Widget build(BuildContext context) {
//     final taskC = Get.find<TaskController>();
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 16),
//         Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
//         const SizedBox(height: 8),
//         ...tasks.map(
//           (t) => Card(
//             color: Colors.grey.shade100,
//             margin: const EdgeInsets.symmetric(vertical: 6),
//             child: ListTile(
//               leading: const Icon(Icons.check_circle, color: Colors.green),
//               title: Text(
//                 t.title,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey),
//               ),
//               subtitle: Row(
//                 children: [
//                   if (t.completedAt != null) ...[
//                     const Icon(Icons.history, size: 16, color: Colors.grey),
//                     const SizedBox(width: 4),
//                     Text('Done: ${fmt(t.completedAt!)}', style: const TextStyle(color: Colors.grey)),
//                   ],
//                 ],
//               ),
//               onTap: () => taskC.toggle(t),
//               onLongPress: () => taskC.remove(t),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// /// ==========================
// /// Unified Add/Edit Task Form
// /// ==========================
// class TaskFormSheet extends StatefulWidget {
//   final Task? initial; // null = Add, non-null = Edit
//   const TaskFormSheet({super.key, this.initial});

//   @override
//   State<TaskFormSheet> createState() => _TaskFormSheetState();
// }

// class _TaskFormSheetState extends State<TaskFormSheet> {
//   late final TextEditingController _title;
//   late final TextEditingController _desc;
//   DateTime? _dueAt;
//   bool _important = false;
//   int _estimate = 0;
//   int _priority = 3;
//   TaskMode _mode = TaskMode.personal;

//   @override
//   void initState() {
//     super.initState();
//     final t = widget.initial;
//     _title = TextEditingController(text: t?.title ?? '');
//     _desc = TextEditingController(text: t?.desc ?? '');
//     _dueAt = t?.dueAt;
//     _important = t?.important ?? false;
//     _estimate = t?.estimateMinutes ?? 0;
//     _priority = t?.priority ?? 3;
//     _mode = t?.mode ?? TaskMode.personal;
//   }

//   @override
//   void dispose() {
//     _title.dispose();
//     _desc.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final taskC = Get.find<TaskController>();
//     final bottomInset = MediaQuery.of(context).viewInsets.bottom;
//     final isEdit = widget.initial != null;

//     return SafeArea(
//       top: false,
//       child: Padding(
//         padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bottomInset + 16),
//         child: SingleChildScrollView(
//           child: Column(mainAxisSize: MainAxisSize.min, children: [
//             Text(isEdit ? 'Edit Task' : 'New Task',
//                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),

//             TextField(
//               controller: _title,
//               decoration: const InputDecoration(labelText: 'Title *'),
//               textInputAction: TextInputAction.next,
//             ),

//             TextField(
//               controller: _desc,
//               decoration: const InputDecoration(labelText: 'Description'),
//               maxLines: 2,
//             ),

//             const SizedBox(height: 8),

//             Row(children: [
//               Expanded(
//                 child: OutlinedButton.icon(
//                   icon: const Icon(Icons.event),
//                   label: Text(_dueAt == null
//                       ? 'Pick Date'
//                       : 'Date: ${_two(_dueAt!.month)}/${_two(_dueAt!.day)}'),
//                   onPressed: () async {
//                     final now = DateTime.now();
//                     final d = await showDatePicker(
//                       context: context,
//                       firstDate: DateTime(now.year - 1),
//                       lastDate: DateTime(now.year + 3),
//                       initialDate: _dueAt ?? now,
//                     );
//                     if (d != null) {
//                       setState(() {
//                         _dueAt = DateTime(d.year, d.month, d.day, _dueAt?.hour ?? 9, _dueAt?.minute ?? 0);
//                       });
//                     }
//                   },
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: OutlinedButton.icon(
//                   icon: const Icon(Icons.access_time),
//                   label: Text(_dueAt == null
//                       ? 'Pick Time'
//                       : 'Time: ${_two(_dueAt!.hour)}:${_two(_dueAt!.minute)}'),
//                   onPressed: () async {
//                     final t = await showTimePicker(
//                       context: context,
//                       initialTime: TimeOfDay.fromDateTime(_dueAt ?? DateTime.now()),
//                     );
//                     if (t != null) {
//                       final base = _dueAt ?? DateTime.now();
//                       setState(() {
//                         _dueAt = DateTime(base.year, base.month, base.day, t.hour, t.minute);
//                       });
//                     }
//                   },
//                 ),
//               ),
//             ]),

//             const SizedBox(height: 8),

//             Row(children: [
//               Expanded(
//                 child: TextField(
//                   keyboardType: TextInputType.number,
//                   decoration: const InputDecoration(labelText: 'Estimate (min)'),
//                   controller: TextEditingController(text: _estimate.toString()),
//                   onChanged: (v) => _estimate = int.tryParse(v) ?? 0,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: DropdownButtonFormField<int>(
//                   value: _priority,
//                   decoration: const InputDecoration(labelText: 'Priority (1-5)'),
//                   items: [1, 2, 3, 4, 5]
//                       .map((p) => DropdownMenuItem(value: p, child: Text('P$p')))
//                       .toList(),
//                   onChanged: (v) => setState(() => _priority = v ?? 3),
//                 ),
//               ),
//             ]),

//             const SizedBox(height: 8),

//             DropdownButtonFormField<TaskMode>(
//               value: _mode,
//               decoration: const InputDecoration(labelText: 'Mode'),
//               items: TaskMode.values
//                   .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
//                   .toList(),
//               onChanged: (v) => setState(() => _mode = v ?? TaskMode.personal),
//             ),

//             const SizedBox(height: 8),

//             SwitchListTile(
//               value: _important,
//               onChanged: (v) => setState(() => _important = v),
//               title: const Text('Important'),
//               subtitle: const Text('Important = higher impact'),
//               contentPadding: EdgeInsets.zero,
//             ),

//             const SizedBox(height: 8),

//             FilledButton.icon(
//               icon: Icon(isEdit ? Icons.save : Icons.add),
//               label: Text(isEdit ? 'Save Changes' : 'Add Task'),
//               onPressed: () {
//                 final title = _title.text.trim();
//                 if (title.isEmpty) return;

//                 if (isEdit) {
//                   taskC.updateLocal(
//                     id: widget.initial!.id,
//                     title: title,
//                     desc: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
//                     dueAt: _dueAt,
//                     important: _important,
//                     estimateMinutes: _estimate,
//                     priority: _priority,
//                     mode: _mode,
//                   );
//                 } else {
//                   // generate a temporary id; server can replace later
//                   final tmpId = 'tmp-${DateTime.now().millisecondsSinceEpoch}';
//                   taskC.createLocal(
//                     id: tmpId,
//                     title: title,
//                     desc: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
//                     dueAt: _dueAt,
//                     important: _important,
//                     estimateMinutes: _estimate,
//                     priority: _priority,
//                     mode: _mode,
//                   );
//                 }
//                 Navigator.pop(context);
//               },
//             ),

//             const SizedBox(height: 8),
//           ]),
//         ),
//       ),
//     );
//   }
// }

// /// ===== Helpers =====
// String _two(int v) => v.toString().padLeft(2, '0');

// String fmt(DateTime dt) =>
//     '${_two(dt.month)}/${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';

// Widget _swipeBg({required bool alignRight}) {
//   final child = Row(
//     mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
//     children: [
//       if (!alignRight) const SizedBox(width: 12),
//       const Icon(Icons.delete, color: Colors.white),
//       const SizedBox(width: 8),
//       const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
//       if (alignRight) const SizedBox(width: 12),
//     ],
//   );
//   return Container(
//     color: Colors.red,
//     padding: const EdgeInsets.symmetric(horizontal: 12),
//     alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
//     child: child,
//   );
// }

// void _openEditSheet(BuildContext context, Task task) {
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     builder: (_) => TaskFormSheet(initial: task),
//   );
// }

// Map<Eisenhower, List<Task>> _groupByEisenhower(List<Task> items, DateTime now) {
//   final map = {for (final e in Eisenhower.values) e: <Task>[]};
//   for (final t in items) {
//     map[classify(t, now)]!.add(t);
//   }
//   for (final e in Eisenhower.values) {
//     map[e]!.sort((a, b) => compareWithinGroup(a, b, now));
//   }
//   return map;
// }

// class _TaskMetaChips extends StatelessWidget {
//   final Task task;
//   const _TaskMetaChips({required this.task});

//   @override
//   Widget build(BuildContext context) {
//     return Wrap(
//       crossAxisAlignment: WrapCrossAlignment.center,
//       spacing: 10,
//       children: [
//         if (task.dueAt != null)
//           Row(mainAxisSize: MainAxisSize.min, children: [
//             const Icon(Icons.schedule, size: 16),
//             const SizedBox(width: 4),
//             Text(fmt(task.dueAt!)),
//           ]),
//         if (task.important) const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
//         if (task.estimateMinutes > 0) Text('${task.estimateMinutes}m'),
//       ],
//     );
//   }
// }

// extension TaskModeLabel on TaskMode {
//   String get label => switch (this) {
//         TaskMode.study => 'Study',
//         // TaskMode.work => 'Work',
//         TaskMode.wellness => 'Wellness',
//         TaskMode.family => 'Family',
//         TaskMode.personal => 'Personal',
//       };
// }

// extension EisenhowerMeta on Eisenhower {
//   String get title => switch (this) {
//         Eisenhower.q1UrgentImportant => 'Urgent & Important',
//         Eisenhower.q2Important => 'Important (Not Urgent)',
//         Eisenhower.q3Urgent => 'Urgent (Not Important)',
//         Eisenhower.q4Other => 'Others',
//       };
// }
