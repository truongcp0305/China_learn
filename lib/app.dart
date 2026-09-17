import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/settings_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';
import 'services/notification_service.dart';
import 'theme.dart';

class ChineseLearnApp extends ConsumerStatefulWidget {
  const ChineseLearnApp({super.key});

  @override
  ConsumerState<ChineseLearnApp> createState() => _ChineseLearnAppState();
}

class _ChineseLearnAppState extends ConsumerState<ChineseLearnApp> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    ref.listen(settingsProvider, (previous, next) {
      final value = next.value;
      if (value == null) return;
      _syncNotifications(value);
    });

    return MaterialApp(
      title: 'Học tiếng Trung',
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: settings.value?.themeMode ?? ThemeMode.system,
      home: settings.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Lỗi: $err'))),
        data: (value) => value.onboarded ? const AppShell() : const OnboardingScreen(),
      ),
    );
  }

  Future<void> _syncNotifications(AppSettings settings) async {
    final service = ref.read(notificationServiceProvider);
    await service.init();
    if (settings.notifyEnabled) {
      await service.scheduleDaily(hour: settings.notifyHour, minute: settings.notifyMinute);
    } else {
      await service.cancelAll();
    }
  }
}
