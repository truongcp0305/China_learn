import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_service.dart';
import '../../theme.dart';
import '../../widgets/app_card.dart';
import 'hsk_goal_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_left, color: AppColors.text),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Text('Cài đặt', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: settings.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Lỗi: $err')),
                  data: (value) => _SettingsBody(settings: value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HskGoalScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mục tiêu HSK', style: TextStyle(fontSize: 15)),
                Row(
                  children: [
                    Text('HSK ${settings.targetHskLevel}',
                        style: const TextStyle(fontSize: 14, color: AppColors.neutral600)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.neutral600),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 10),
        const _SectionLabel('Giao diện'),
        const SizedBox(height: 10),
        AppCard(
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Hệ thống')),
              ButtonSegment(value: ThemeMode.light, label: Text('Sáng')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Tối')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) => notifier.setThemeMode(selection.first),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Nhắc ôn tập hàng ngày'),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bật nhắc nhở', style: TextStyle(fontSize: 15)),
                  Switch(
                    value: settings.notifyEnabled,
                    onChanged: (value) => notifier.setNotifyEnabled(value),
                  ),
                ],
              ),
              if (settings.notifyEnabled) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: settings.notifyHour, minute: settings.notifyMinute),
                    );
                    if (picked != null) {
                      await notifier.setNotifyTime(hour: picked.hour, minute: picked.minute);
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Giờ nhắc', style: TextStyle(fontSize: 15)),
                      Text(
                        '${settings.notifyHour.toString().padLeft(2, '0')}:${settings.notifyMinute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 15, color: AppColors.accent700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, letterSpacing: 1.0, color: AppColors.neutral600),
    );
  }
}
