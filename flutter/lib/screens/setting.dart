// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/settingController.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingC = Get.find<SettingController>();

    final hourOptions = List<int>.generate(12, (i) => i + 1);

    Widget hourDropdown({
      required RxInt value,
      required void Function(int) onChanged,
    }) {
      return Obx(() {
        return DropdownButton<int>(
          value: value.value,
          items: hourOptions
              .map((h) => DropdownMenuItem(
                    value: h,
                    child: Text('$h hour${h == 1 ? '' : 's'}'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Repeat reminders (only on due day)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // Urgent & High info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Urgent: every 1 hour (always)'),
                  SizedBox(height: 6),
                  Text('High: every 2 hours (always)'),
                  SizedBox(height: 6),
                  Text('Medium/Low: configurable below'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Medium
          Obx(() {
            return SwitchListTile(
              title: const Text('Enable Medium repeat'),
              subtitle: const Text('If enabled, repeats on due day only'),
              value: settingC.mediumRepeatEnabled.value,
              onChanged: (v) => settingC.setMediumEnabled(v),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Medium interval:  '),
                hourDropdown(
                  value: settingC.mediumRepeatHours,
                  onChanged: settingC.setMediumHours,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Low
          Obx(() {
            return SwitchListTile(
              title: const Text('Enable Low repeat'),
              subtitle: const Text('If enabled, repeats on due day only'),
              value: settingC.lowRepeatEnabled.value,
              onChanged: (v) => settingC.setLowEnabled(v),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Low interval:      '),
                hourDropdown(
                  value: settingC.lowRepeatHours,
                  onChanged: settingC.setLowHours,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Friendly note
          const Text(
            'Note: Due-today notification will always fire at least once even if you disable task notifications.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
