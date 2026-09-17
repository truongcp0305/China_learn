import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../theme.dart';
import '../../widgets/app_card.dart';
import '../settings/hsk_goal_screen.dart';

const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final goal = ref.watch(goalProgressProvider);

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
                  const SizedBox(width: 6),
                  Text('Tiến độ', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: progress.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Lỗi: $err')),
                  data: (data) => SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        goal.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (g) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Mục tiêu · HSK ${g.targetLevel}',
                                      style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
                                  Text('${g.percent}%',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: g.ratio.clamp(0, 1),
                                  minHeight: 8,
                                  backgroundColor: AppColors.neutral200,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${g.mastered} / ${g.total} từ đã thuộc — còn ${g.remaining} từ để đạt HSK ${g.targetLevel}',
                                style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const HskGoalScreen()),
                                ),
                                child: const Text('Đổi mục tiêu →'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        AppCard(
                          kicker: 'Streak',
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 38, color: AppColors.text),
                              children: [
                                TextSpan(text: '${data.streakDays} '),
                                const TextSpan(
                                  text: 'ngày liên tiếp',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const _SectionLabel('Theo cấp độ HSK'),
                        const SizedBox(height: 12),
                        for (final level in data.byLevel) ...[
                          _LevelBar(level: level),
                          const SizedBox(height: 14),
                        ],
                        const SizedBox(height: 14),
                        const _SectionLabel('7 ngày qua'),
                        const SizedBox(height: 16),
                        _WeekChart(counts: data.weekCounts),
                      ],
                    ),
                  ),
                ),
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
    return Text(text, style: const TextStyle(fontSize: 13, letterSpacing: 1.0, color: AppColors.neutral600));
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level});
  final LevelCount level;

  @override
  Widget build(BuildContext context) {
    final ratio = level.total == 0 ? 0.0 : level.mastered / level.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('HSK ${level.level}', style: const TextStyle(fontSize: 13)),
            Text('${level.mastered} / ${level.total}', style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 6,
            backgroundColor: AppColors.neutral200,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.counts});
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.fold<int>(1, (m, c) => c > m ? c : m);
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < counts.length; i++)
                Container(
                  width: 22,
                  height: counts[i] == 0 ? 4 : 90 * (counts[i] / maxCount).clamp(0.08, 1.0),
                  decoration: BoxDecoration(
                    color: counts[i] == maxCount && maxCount > 0 ? AppColors.accent : AppColors.accent200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in _weekdayShort)
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
          ],
        ),
      ],
    );
  }
}
