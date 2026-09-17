import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_service.dart';
import '../../theme.dart';
import '../shell/app_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _hskLevel = '1';
  int _dailyGoal = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Học tiếng Trung',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                      color: AppColors.accent700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Từ vựng & ôn tập ngắt quãng.',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 34, height: 1.15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Học từ mới mỗi ngày, ôn lại đúng lúc trước khi quên — theo thuật toán lặp lại cách quãng.',
                    style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.neutral700),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Chọn cấp độ HSK'),
                  const SizedBox(height: 10),
                  _Segmented(
                    options: const ['HSK 1', 'HSK 2', 'HSK 3'],
                    selectedIndex: int.parse(_hskLevel) - 1,
                    onSelected: (i) => setState(() => _hskLevel = '${i + 1}'),
                  ),
                  const SizedBox(height: 24),
                  const _SectionLabel('Mục tiêu mỗi ngày'),
                  const SizedBox(height: 10),
                  _Segmented(
                    options: const ['10 từ', '20 từ', '40 từ'],
                    selectedIndex: [10, 20, 40].indexOf(_dailyGoal),
                    onSelected: (i) => setState(() => _dailyGoal = [10, 20, 40][i]),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(settingsProvider.notifier)
                            .completeOnboarding(hskLevel: _hskLevel, dailyGoal: _dailyGoal);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const AppShell()),
                          );
                        }
                      },
                      child: const Text('Bắt đầu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      style: const TextStyle(
        fontSize: 13,
        letterSpacing: 1.0,
        textBaseline: TextBaseline.alphabetic,
        color: AppColors.neutral600,
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.selectedIndex, required this.onSelected});

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? AppColors.accent : Colors.transparent,
                    border: i > 0 ? const Border(left: BorderSide(color: AppColors.divider)) : null,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: i == selectedIndex ? AppColors.bg : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
