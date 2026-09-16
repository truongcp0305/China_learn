import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/srs.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<ReviewCard> _queue = [];
  Word? _currentWord;
  bool _showAnswer = false;
  bool _loading = true;

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
      _loading = false;
    });
    await _loadCurrentWord();
  }

  Future<void> _loadCurrentWord() async {
    if (_queue.isEmpty) {
      setState(() => _currentWord = null);
      return;
    }
    final db = ref.read(databaseProvider);
    final word = await db.wordById(_queue.first.wordId);
    setState(() {
      _currentWord = word;
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
      wordId: Value(card.wordId),
      easeFactor: Value(result.easeFactor),
      intervalDays: Value(result.intervalDays),
      repetitions: Value(result.repetitions),
      dueDate: Value(DateTime.now().add(Duration(days: result.intervalDays))),
      lastReviewed: Value(DateTime.now()),
    ));

    setState(() => _queue = _queue.skip(1).toList());
    await _loadCurrentWord();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ôn tập')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _currentWord == null
              ? const Center(child: Text('Không còn thẻ nào cần ôn hôm nay 🎉'))
              : _buildCard(_currentWord!),
    );
  }

  Widget _buildCard(Word word) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(word.simplified, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          if (_showAnswer) ...[
            Text(word.pinyin, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(word.meaning, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              children: [
                _gradeButton('Quên', 1),
                _gradeButton('Khó', 3),
                _gradeButton('Tốt', 4),
                _gradeButton('Dễ', 5),
              ],
            ),
          ] else
            FilledButton(
              onPressed: () => setState(() => _showAnswer = true),
              child: const Text('Hiện đáp án'),
            ),
        ],
      ),
    );
  }

  Widget _gradeButton(String label, int quality) {
    return OutlinedButton(
      onPressed: () => _grade(quality),
      child: Text(label),
    );
  }
}
