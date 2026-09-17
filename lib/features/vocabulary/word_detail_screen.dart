import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../services/tts_service.dart';
import '../../theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/hsk_tag.dart';

class WordDetailScreen extends ConsumerWidget {
  const WordDetailScreen({super.key, required this.word});

  final Word word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardAsync = ref.watch(_reviewCardProvider(word.id));

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
              Text(word.simplified, style: const TextStyle(fontSize: 64, height: 1)),
              const SizedBox(height: 10),
              Text(word.pinyin,
                  style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic, color: AppColors.accent700)),
              const SizedBox(height: 4),
              Text(word.meaning, style: const TextStyle(fontSize: 16, color: AppColors.neutral800)),
              if (word.hanViet != null) ...[
                const SizedBox(height: 2),
                Text('Hán Việt: ${word.hanViet}',
                    style: const TextStyle(fontSize: 14, color: AppColors.neutral700)),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (word.hskLevel != null) HskTag(word.hskLevel!),
                  if (word.partOfSpeech != null) ...[
                    const SizedBox(width: 8),
                    LabelTag(word.partOfSpeech!),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => ref.read(ttsServiceProvider).speak(word.simplified),
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                label: const Text('Nghe phát âm'),
              ),
              const SizedBox(height: 28),
              const SectionLabel('Thứ tự nét viết'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
                    child: Text(word.simplified,
                        style: const TextStyle(fontSize: 52, color: AppColors.neutral300)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LabelTag('Sắp có', tone: LabelTagTone.neutral),
                        SizedBox(height: 8),
                        Text('Hoạt ảnh thứ tự nét viết cho từng chữ Hán.',
                            style: TextStyle(fontSize: 13, color: AppColors.neutral700)),
                      ],
                    ),
                  ),
                ],
              ),
              if (word.exampleZh != null) ...[
                const SizedBox(height: 26),
                const SectionLabel('Ví dụ'),
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word.exampleZh!, style: const TextStyle(fontSize: 18)),
                      if (word.examplePinyin != null) ...[
                        const SizedBox(height: 4),
                        Text(word.examplePinyin!,
                            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.accent700)),
                      ],
                      if (word.exampleVi != null) ...[
                        const SizedBox(height: 6),
                        Text(word.exampleVi!, style: const TextStyle(fontSize: 13, color: AppColors.neutral800)),
                      ],
                    ],
                  ),
                ),
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
    FutureProvider.autoDispose.family<ReviewCard?, int>((ref, wordId) {
  return ref.watch(databaseProvider).reviewCardForItem(kItemTypeWord, wordId);
});
