// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/taskController.dart';
import '../controller/petController.dart';
import '../controller/userController.dart';
import '../widget/pet_card.dart';
import '../widget/task_group_tile.dart';
import 'group_tasks_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TaskController taskC = Get.find();
  final PetController petC = Get.find();
  final userC = Get.find<UserController>();

   @override
  void initState() {
    super.initState();
    final uid = userC.userId.value;
    taskC.loadByUser(uid);
    petC.fetchRisk(uid);
  }

  Color _colorFor(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return const Color(0xFF5C45FF);
      case 'personal':
        return const Color(0xFF7B61FF);
      case 'private':
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFF5C45FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final uid = userC.userId.value;
            await Future.wait([
              taskC.loadByUser(uid),
              petC.fetchRisk(uid),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header
                Row(
                  children: [
                    const CircleAvatar(radius: 20, backgroundImage: AssetImage('assets/avatar.png')),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hello!", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                        Text("Your buddy awaits 🐾", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                  ],
                ),
                const SizedBox(height: 16),

                // PET CARD (replaces In Progress)
                Obx(() => PetCard(
                  risk: petC.risk.value,
                  onTapViewTask: () {
                    // choose the category with lowest completion and open it
                    final groups = taskC.groupedByCategory();
                    String? target;
                    double worst = 2;
                    groups.forEach((k, v) {
                      final c = taskC.completionFor(k);
                      if (c < worst) { worst = c; target = k; }
                    });
                    if (target != null) {
                      Get.to(() => GroupTasksPage(category: target!, taskC: taskC, userId: null,));
                    }
                  },
                )),
                const SizedBox(height: 24),

                Text('Task Groups', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                Obx(() {
                  final groups = taskC.groupedByCategory();
                  if (taskC.loading.value) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (groups.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No tasks yet. Create one to get started!'),
                    );
                  }
                  return Column(
                    children: groups.entries.map((e) {
                      final color = _colorFor(e.key);
                      final completion = taskC.completionFor(e.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: TaskGroupTile(
                          title: e.key,
                          count: e.value.length,
                          completion: completion,
                          color: color,
                          onTap: () => Get.to(() => GroupTasksPage(category: e.key, taskC: taskC, userId: userC.userId.value,)),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.snackbar('New', 'Open create-task sheet here'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
