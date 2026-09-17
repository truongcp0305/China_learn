import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/hsk_tag.dart';
import '../progress/progress_screen.dart';
import '../review/review_screen.dart';
import '../settings/hsk_goal_screen.dart';
import '../settings/settings_screen.dart';
import '../vocabulary/vocabulary_list_screen.dart';

const _weekdayNames = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(seedProvider);

    return Scaffold(
      body: SafeArea(
        child: seed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Lỗi nạp dữ liệu: $err')),
          data: (_) => const _HomeBody(),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueCardsProvider);
    final progress = ref.watch(progressProvider);
    final recent = ref.watch(recentWordsProvider);
    final goal = ref.watch(goalProgressProvider);
    final currentLevel = ref.watch(currentEstimatedLevelProvider);
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_weekdayNames[now.weekday - 1]} · ${now.day} Tháng ${now.month}',
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: AppColors.neutral600,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.settings_outlined, color: AppColors.neutral700, size: 20),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Học tiếng Trung', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Trình độ hiện tại', style: TextStyle(fontSize: 14, color: AppColors.neutral700)),
              const SizedBox(width: 8),
              currentLevel.when(
                data: (level) => HskTag(level),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 22),
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
                    Text('${g.percent}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
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
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const HskGoalScreen())),
                  child: const Text('Đổi mục tiêu →'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  kicker: 'Cần ôn',
                  child: _StatValue(
                    value: due.whenOrNull(data: (d) => '${d.length}') ?? '–',
                    suffix: 'từ hôm nay',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  kicker: 'Đã học',
                  child: _StatValue(
                    value: progress.whenOrNull(data: (p) => '${p.learnedTotal}') ?? '–',
                    suffix: 'tổng số từ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ReviewScreen())),
              child: const Text('Ôn tập (SRS)'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const VocabularyListScreen())),
              child: const Text('Danh sách từ vựng'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProgressScreen())),
            child: const Text('Xem tiến độ →'),
          ),
          const SizedBox(height: 24),
          const Text(
            'GẦN ĐÂY',
            style: TextStyle(fontSize: 13, letterSpacing: 1.0, color: AppColors.neutral600),
          ),
          recent.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Text('Lỗi: $err'),
            data: (words) {
              if (words.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Chưa có từ nào được ôn tập.',
                    style: TextStyle(fontSize: 13, color: AppColors.neutral700),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < words.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: i < words.length - 1
                            ? const Border(bottom: BorderSide(color: AppColors.divider))
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          SizedBox(
                            width: 46,
                            child: Text(words[i].simplified, style: const TextStyle(fontSize: 22)),
                          ),
                          Expanded(
                            child: Text(
                              words[i].pinyin,
                              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.accent700),
                            ),
                          ),
                          Text(words[i].meaning, style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.value, required this.suffix});
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
        Text(suffix, style: const TextStyle(fontSize: 13, color: AppColors.neutral800)),
      ],
    );
  }
}
