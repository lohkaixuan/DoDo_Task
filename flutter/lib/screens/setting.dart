// lib/screens/setting.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/settingController.dart';
import 'package:v3/services/notification_service.dart';


class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingC = Get.find<SettingController>();
    final notifier = Get.find<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionTitle('Notifications'),

          // ─────────────────────────────────────────────
          // System notification permission helper
          // ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Notification Permission',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If you don’t receive reminders, enable notifications in OS settings.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final enabled = await notifier.areEnabled();
                            if (enabled) {
                              Get.snackbar('All good 🦈',
                                  'Notifications are already enabled.');
                              return;
                            }

                            
                            final ok = await notifier.ensurePermission();
                            if (ok) {
                              Get.snackbar(
                                  'Enabled 🎉', 'Task reminders are ready!');
                            } else {
                              await notifier.openAppNotificationSettings();
                            }
                          },
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('Enable Notifications'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ─────────────────────────────────────────────
          // Repeat rules by priority (your new requirement)
          // ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Obx(() {
                final hourOptions = List<int>.generate(12, (i) => i + 1);

                Widget hourDropdown({
                  required RxInt value,
                  required void Function(int) onChanged,
                }) {
                  return DropdownButton<int>(
                    value: value.value,
                    items: hourOptions
                        .map(
                          (h) => DropdownMenuItem(
                            value: h,
                            child: Text('$h hour${h == 1 ? '' : 's'}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      onChanged(v);
                    },
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Repeat Reminders (Due day only)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    ElevatedButton(
  onPressed: () async => notifier.showNowTest(),
  child: const Text("Test Notification Now"),
),
                    const SizedBox(height: 8),
                    const Text(
                      'Rules:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text('• Urgent: every 1 hour (always)'),
                    const Text('• High: every 2 hours (always)'),
                    const Text('• Medium / Low: user choice below'),
                    const SizedBox(height: 8),
                    const Text(
                      'Note: If a task is due today, it will still notify at least once.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),

                    const Divider(height: 24),

                    // Medium
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Medium repeat'),
                      subtitle: const Text('Only affects tasks due today'),
                      value: settingC.mediumRepeatEnabled.value,
                      onChanged: settingC.setMediumEnabled,
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Text('Medium interval:  '),
                        const SizedBox(width: 8),
                        hourDropdown(
                          value: settingC.mediumRepeatHours,
                          onChanged: settingC.setMediumHours,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Low
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Low repeat'),
                      subtitle: const Text('Only affects tasks due today'),
                      value: settingC.lowRepeatEnabled.value,
                      onChanged: settingC.setLowEnabled,
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Text('Low interval:      '),
                        const SizedBox(width: 8),
                        hourDropdown(
                          value: settingC.lowRepeatHours,
                          onChanged: settingC.setLowHours,
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 12),

          _sectionTitle('About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Dodo Task 🦈',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Priority reminders:\n'
                    '- Urgent: 1h\n'
                    '- High: 2h\n'
                    '- Medium/Low: configurable\n'
                    'Due-today always notifies at least once.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
        ),
      ),
    );
  }
}
