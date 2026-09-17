import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/srs.dart';
import '../../services/tts_service.dart';
import '../../theme.dart';
import '../../widgets/hsk_tag.dart';
import 'review_result_screen.dart';

enum _ReviewMode { readFirst, listenFirst }

/// Either a [Word] or a [GrammarPoint] — whichever [ReviewCard.itemType] on
/// the current queue entry points to.
class _ReviewItem {
  const _ReviewItem.word(this.word) : grammar = null;
  const _ReviewItem.grammar(this.grammar) : word = null;

  final Word? word;
  final GrammarPoint? grammar;

  bool get isGrammar => grammar != null;
  String get frontText => word?.simplified ?? grammar!.titleZh;
}

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<ReviewCard> _queue = [];
  int _totalCount = 0;
  _ReviewItem? _currentItem;
  bool _showAnswer = false;
  bool _loading = true;
  _ReviewMode _mode = _ReviewMode.readFirst;
  int _gradedGood = 0;
  int _gradedWords = 0;
  int _gradedGrammar = 0;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final db = ref.read(databaseProvider);
    final due = await db.dueCards();
    setState(() {
      _queue = due;
      _totalCount = due.length;
      _loading = false;
    });
    await _loadCurrentItem();
  }

  Future<void> _loadCurrentItem() async {
    if (_queue.isEmpty) {
      setState(() => _currentItem = null);
      return;
    }
    final db = ref.read(databaseProvider);
    final card = _queue.first;
    final item = card.itemType == kItemTypeGrammar
        ? _ReviewItem.grammar(await db.grammarPointById(card.itemId))
        : _ReviewItem.word(await db.wordById(card.itemId));
    setState(() {
      _currentItem = item;
      _showAnswer = false;
    });
  }

  Future<void> _grade(int quality) async {
    final db = ref.read(databaseProvider);
    final card = _queue.first;
    final result = calculateNextReview(
      easeFactor: card.easeFactor,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
      quality: quality,
    );

    await db.upsertReviewCard(ReviewCardsCompanion(
      id: Value(card.id),
      itemType: Value(card.itemType),
      itemId: Value(card.itemId),
      easeFactor: Value(result.easeFactor),
      intervalDays: Value(result.intervalDays),
      repetitions: Value(result.repetitions),
      dueDate: Value(DateTime.now().add(Duration(days: result.intervalDays))),
      lastReviewed: Value(DateTime.now()),
    ));
    await db.insertReviewLog(card.itemType, card.itemId);

    ref.invalidate(dueCardsProvider);
    ref.invalidate(progressProvider);
    ref.invalidate(recentWordsProvider);

    setState(() {
      if (quality >= 4) _gradedGood++;
      if (card.itemType == kItemTypeGrammar) {
        _gradedGrammar++;
      } else {
        _gradedWords++;
      }
      _queue = _queue.skip(1).toList();
    });

    if (_queue.isEmpty) {
      final streak = await ref.read(progressProvider.future).then((p) => p.streakDays);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ReviewResultScreen(
          totalReviewed: _totalCount,
          goodCount: _gradedGood,
          wordCount: _gradedWords,
          grammarCount: _gradedGrammar,
          streakDays: streak,
        ),
      ));
      return;
    }
    await _loadCurrentItem();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.chevron_left, color: AppColors.text),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(width: 4),
                            Text('Ôn tập', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
                          ],
                        ),
                        Text(
                          '${_totalCount - _queue.length + (_currentItem != null ? 1 : 0)} / $_totalCount',
                          style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _totalCount == 0
                            ? 0
                            : (_totalCount - _queue.length) / _totalCount,
                        minHeight: 3,
                        backgroundColor: AppColors.neutral200,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    ),
                    if (_currentItem != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          LabelTag(
                            _currentItem!.isGrammar ? 'Ngữ pháp' : 'Từ vựng',
                            tone: _currentItem!.isGrammar ? LabelTagTone.accent2 : LabelTagTone.accent,
                          ),
                          SegmentedButton<_ReviewMode>(
                            segments: const [
                              ButtonSegment(value: _ReviewMode.readFirst, label: Text('Xem chữ')),
                              ButtonSegment(value: _ReviewMode.listenFirst, label: Text('Nghe trước')),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (selection) => setState(() {
                              _mode = selection.first;
                              _showAnswer = false;
                            }),
                          ),
                        ],
                      ),
                    ],
                    Expanded(
                      child: _currentItem == null
                          ? const Center(child: Text('Không còn thẻ nào cần ôn hôm nay 🎉'))
                          : _buildCard(_currentItem!),
                    ),
                    if (_currentItem != null && _showAnswer)
                      Row(
                        children: [
                          Expanded(child: _gradeButton('Quên', 1, style: _GradeStyle.secondary)),
                          const SizedBox(width: 8),
                          Expanded(child: _gradeButton('Khó', 3, style: _GradeStyle.hard)),
                          const SizedBox(width: 8),
                          Expanded(child: _gradeButton('Tốt', 4, style: _GradeStyle.good)),
                          const SizedBox(width: 8),
                          Expanded(child: _gradeButton('Dễ', 5, style: _GradeStyle.easy)),
                        ],
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCard(_ReviewItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_showAnswer) setState(() => _showAnswer = true);
      },
      child: _mode == _ReviewMode.listenFirst && !_showAnswer
          ? _buildListenFront(item)
          : _buildReadFront(item),
    );
  }

  Widget _buildListenFront(_ReviewItem item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => ref.read(ttsServiceProvider).speak(item.frontText),
          icon: const Icon(Icons.volume_up, color: AppColors.accent800),
          iconSize: 24,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.accent100,
            padding: const EdgeInsets.all(20),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          item.isGrammar ? 'Nghe câu ví dụ, đoán cấu trúc' : 'Nghe rồi đoán nghĩa',
          style: const TextStyle(fontSize: 15, color: AppColors.neutral800),
        ),
        if (item.isGrammar && item.grammar!.hskLevel != null) ...[
          const SizedBox(height: 6),
          Text(
            '${item.grammar!.titleZh} · HSK${item.grammar!.hskLevel}',
            style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
          ),
        ] else if (!item.isGrammar && item.word!.hskLevel != null) ...[
          const SizedBox(height: 6),
          Text('HSK${item.word!.hskLevel}', style: const TextStyle(fontSize: 13, color: AppColors.neutral600)),
        ],
      ],
    );
  }

  Widget _buildReadFront(_ReviewItem item) {
    if (item.isGrammar) {
      final grammar = item.grammar!;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(grammar.titleZh, style: const TextStyle(fontSize: 64, height: 1)),
          const SizedBox(height: 14),
          Text(grammar.titleVi, style: const TextStyle(fontSize: 17, color: AppColors.neutral800), textAlign: TextAlign.center),
          if (_showAnswer) ...[
            const SizedBox(height: 10),
            Text(grammar.pattern,
                style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: AppColors.accent700),
                textAlign: TextAlign.center),
          ] else ...[
            const SizedBox(height: 24),
            const Text('Chạm để xem cấu trúc', style: TextStyle(fontSize: 13, color: AppColors.neutral600)),
          ],
        ],
      );
    }

    final word = item.word!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(word.simplified, style: const TextStyle(fontSize: 84, height: 1)),
        if (_showAnswer) ...[
          const SizedBox(height: 14),
          Text(word.pinyin,
              style: const TextStyle(fontSize: 22, fontStyle: FontStyle.italic, color: AppColors.accent700)),
          const SizedBox(height: 6),
          Text(word.meaning, style: const TextStyle(fontSize: 17, color: AppColors.neutral800)),
        ] else ...[
          const SizedBox(height: 24),
          const Text('Chạm để xem đáp án', style: TextStyle(fontSize: 13, color: AppColors.neutral600)),
        ],
      ],
    );
  }

  Widget _gradeButton(String label, int quality, {required _GradeStyle style}) {
    final Color bg;
    final Color fg;
    switch (style) {
      case _GradeStyle.secondary:
        bg = Colors.transparent;
        fg = AppColors.text;
        break;
      case _GradeStyle.hard:
        bg = AppColors.accent2_100;
        fg = AppColors.accent2_800;
        break;
      case _GradeStyle.good:
        bg = AppColors.accent100;
        fg = AppColors.accent800;
        break;
      case _GradeStyle.easy:
        bg = AppColors.accent;
        fg = AppColors.bg;
        break;
    }
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () => _grade(quality),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: style == _GradeStyle.secondary ? const BorderSide(color: AppColors.divider) : BorderSide.none,
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

enum _GradeStyle { secondary, hard, good, easy }
