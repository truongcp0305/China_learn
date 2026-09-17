import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/hsk_tag.dart';

class GrammarDetailScreen extends ConsumerStatefulWidget {
  const GrammarDetailScreen({super.key, required this.point});

  final GrammarPoint point;

  @override
  ConsumerState<GrammarDetailScreen> createState() => _GrammarDetailScreenState();
}

class _GrammarDetailScreenState extends ConsumerState<GrammarDetailScreen> {
  @override
  void initState() {
    super.initState();
    // A review card is only created once the grammar point has been opened —
    // same "create on first study" rule as words.
    ref.read(databaseProvider).ensureReviewCardExists(kItemTypeGrammar, widget.point.id);
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final cardAsync = ref.watch(_reviewCardProvider(point.id));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_left, color: AppColors.text),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              Text(point.titleZh, style: const TextStyle(fontSize: 56, height: 1)),
              const SizedBox(height: 10),
              Text(point.titleVi, style: const TextStyle(fontSize: 16, color: AppColors.neutral800)),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (point.hskLevel != null) HskTag(point.hskLevel!),
                  const SizedBox(width: 8),
                  const LabelTag('ngữ pháp', tone: LabelTagTone.accent2),
                ],
              ),
              const SizedBox(height: 28),
              const SectionLabel('Cấu trúc'),
              const SizedBox(height: 10),
              Text(point.pattern, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
              const SizedBox(height: 22),
              const SectionLabel('Giải thích'),
              const SizedBox(height: 10),
              Text(point.explanationVi,
                  style: const TextStyle(fontSize: 14, height: 1.65, color: AppColors.neutral800)),
              const SizedBox(height: 24),
              const SectionLabel('Ví dụ'),
              const SizedBox(height: 10),
              if (point.example1Zh != null) _ExampleCard(zh: point.example1Zh!, pinyin: point.example1Pinyin, vi: point.example1Vi),
              if (point.example2Zh != null) ...[
                const SizedBox(height: 14),
                _ExampleCard(zh: point.example2Zh!, pinyin: point.example2Pinyin, vi: point.example2Vi),
              ],
              const SizedBox(height: 26),
              const SectionLabel('Ôn tập'),
              const SizedBox(height: 6),
              cardAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Lỗi: $err'),
                data: (card) {
                  if (card == null) {
                    return const MetaRow(label: 'Trạng thái', value: 'Chưa ôn lần nào');
                  }
                  return Column(
                    children: [
                      MetaRow(label: 'Lần ôn gần nhất', value: _describeLastReviewed(card.lastReviewed)),
                      MetaRow(label: 'Lần ôn tiếp theo', value: _describeNextReview(card.dueDate)),
                      MetaRow(label: 'Độ dễ nhớ', value: null, tag: _memorabilityTag(card.easeFactor)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _describeLastReviewed(DateTime? last) {
    if (last == null) return 'Chưa ôn lần nào';
    final days = DateTime.now().difference(last).inDays;
    if (days <= 0) return 'Hôm nay';
    return '$days ngày trước';
  }

  String _describeNextReview(DateTime due) {
    final days = due.difference(DateTime.now()).inDays;
    if (days <= 0) return 'Hôm nay';
    return '$days ngày nữa';
  }

  Widget _memorabilityTag(double easeFactor) {
    if (easeFactor >= 2.5) return const LabelTag('Tốt', tone: LabelTagTone.accent);
    if (easeFactor >= 2.0) return const LabelTag('Khá', tone: LabelTagTone.accent2);
    return const LabelTag('Kém', tone: LabelTagTone.neutral);
  }
}

final _reviewCardProvider =
    FutureProvider.autoDispose.family<ReviewCard?, int>((ref, grammarId) {
  return ref.watch(databaseProvider).reviewCardForItem(kItemTypeGrammar, grammarId);
});

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.zh, this.pinyin, this.vi});
  final String zh;
  final String? pinyin;
  final String? vi;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(zh, style: const TextStyle(fontSize: 18)),
          if (pinyin != null) ...[
            const SizedBox(height: 4),
            Text(pinyin!, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.accent700)),
          ],
          if (vi != null) ...[
            const SizedBox(height: 6),
            Text(vi!, style: const TextStyle(fontSize: 13, color: AppColors.neutral800)),
          ],
        ],
      ),
    );
  }
}
