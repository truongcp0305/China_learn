import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings_service.dart';
import '../../theme.dart';

const _hskGoals = [
  (level: '1', words: 120, color: AppColors.accent200),
  (level: '2', words: 150, color: AppColors.accent200),
  (level: '3', words: 180, color: AppColors.accent),
  (level: '4', words: 300, color: AppColors.accent700),
  (level: '5', words: 600, color: AppColors.accent800),
  (level: '6', words: 750, color: AppColors.accent2_700),
];

class HskGoalScreen extends ConsumerStatefulWidget {
  const HskGoalScreen({super.key});

  @override
  ConsumerState<HskGoalScreen> createState() => _HskGoalScreenState();
}

class _HskGoalScreenState extends ConsumerState<HskGoalScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final goalAsync = ref.watch(goalProgressProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Lỗi: $err')),
            data: (settings) {
              final selected = _selected ?? settings.targetHskLevel;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_left, color: AppColors.text),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text('Mục tiêu HSK', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26)),
                  const SizedBox(height: 6),
                  const Text(
                    'Chọn cấp độ bạn muốn đạt. Tiến độ ở Tổng quan sẽ tính theo mục tiêu này.',
                    style: TextStyle(fontSize: 14, color: AppColors.neutral700),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final goal in _hskGoals)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: goal.level,
                              groupValue: selected,
                              onChanged: (value) => setState(() => _selected = value),
                              title: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: goal.color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text('HSK ${goal.level}')),
                                  Text('${goal.words} từ',
                                      style: const TextStyle(fontSize: 12, color: AppColors.neutral600)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          const Text('TÓM TẮT',
                              style: TextStyle(fontSize: 13, letterSpacing: 1.0, color: AppColors.neutral600)),
                          const SizedBox(height: 14),
                          goalAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, _) => Text('Lỗi: $err'),
                            data: (goal) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Đã thuộc tính đến HSK ${goal.targetLevel}',
                                        style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
                                    Text('${goal.percent}%',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 20, fontFamily: 'Roboto')),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: goal.ratio.clamp(0, 1),
                                    minHeight: 8,
                                    backgroundColor: AppColors.neutral200,
                                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${goal.mastered} / ${goal.total} từ đã thuộc — còn ${goal.remaining} từ '
                                  'cần học để đạt HSK ${goal.targetLevel}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await ref.read(settingsProvider.notifier).setTargetHskLevel(selected);
                        ref.invalidate(goalProgressProvider);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Text('Lưu mục tiêu'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
