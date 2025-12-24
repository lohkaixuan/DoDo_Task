import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/taskController.dart';
import '../controller/petController.dart';
import '../screens/add_update_task.dart';
import '../screens/all_task.dart';
import '../screens/dashboard.dart';
import '../screens/setting.dart';
import '../screens/task_today.dart';
import '../widgets/pet_chat_head.dart';

/// Reserve a little space at the very end of tall lists so the bar/bubble
/// never covers the last item.
const double kBottomReserve = 100.0;

class NavShell extends StatefulWidget {
  const NavShell({super.key});
  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  int _index = 0;

  final _tabs = const [
    Dashboard(),       // 0
    TaskToday(),       // 1
    SizedBox.shrink(), // 2 (center slot; not a page)
    AllTasks(),        // 3
    SettingPage(),  // 4
  ];

  Future<void> _openAddSheet() async {
    final tc = Get.find<TaskController>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddUpdateTaskSheet(controller: tc),
    );
  }

  @override
  Widget build(BuildContext context) {
    // keep the body drawing under the bar for smooth shadows
    return Scaffold(
      extendBody: true,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          IndexedStack(index: _index, children: _tabs),
          // draggable pet head (reacts to emotion → picks sprite)
          const PetHeadFloating(bottomReserve: 88, size: 56),

        ],
      ),

      // custom bottom bar (no notch, no FAB) – prevents overflow on all phones
      bottomNavigationBar: _BottomBar(
        currentIndex: _index,
        onIndex: (i) => setState(() => _index = i),
        onAdd: _openAddSheet,
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Bottom bar: 5 equal items (Dashboard · Today · + · All · Settings)
/// Uses SafeArea and dynamic bottom padding so it NEVER overflows.
/// Icons are uniform (size 24), labels size 11.
/// ---------------------------------------------------------------------------
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onIndex,
    required this.onAdd,
  });

  final int currentIndex;
  final ValueChanged<int> onIndex;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safe = MediaQuery.of(context).padding.bottom;
    // give at least 8px breathing room; this removes the red overflow strip
    final bottomPad = (safe < 8 ? 8.0 : safe);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: Container(
        height: 64 + bottomPad,
        padding: EdgeInsets.only(left: 8, right: 8, top: 6, bottom: bottomPad),
        child: Row(
          children: [
            Expanded(
              child: _BarItem(
                icon: Icons.explore_outlined,
                label: 'Dashboard',
                selected: currentIndex == 0,
                onTap: () => onIndex(0),
              ),
            ),
            Expanded(
              child: _BarItem(
                icon: Icons.today_outlined,
                label: 'Today',
                selected: currentIndex == 1,
                onTap: () => onIndex(1),
              ),
            ),
            // center add – same footprint as other items; visible on any device
            Expanded(child: _CenterAddButton(onTap: onAdd)),
            Expanded(
              child: _BarItem(
                icon: Icons.view_agenda_outlined,
                label: 'All',
                selected: currentIndex == 3,
                onTap: () => onIndex(3),
              ),
            ),
            Expanded(
              child: _BarItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: currentIndex == 4,
                onTap: () => onIndex(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey;
    final weight = selected ? FontWeight.w700 : FontWeight.w500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: weight, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  const _CenterAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          width: 52, // same visual weight as other items
          decoration: BoxDecoration(
            color: c.withOpacity(.14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.add, color: c, size: 22),
        ),
      ),
    );
  }
}
