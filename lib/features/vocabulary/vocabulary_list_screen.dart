import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../theme.dart';
import '../../widgets/hsk_tag.dart';
import 'word_detail_screen.dart';

class VocabularyListScreen extends ConsumerStatefulWidget {
  const VocabularyListScreen({super.key});

  @override
  ConsumerState<VocabularyListScreen> createState() => _VocabularyListScreenState();
}

class _VocabularyListScreenState extends ConsumerState<VocabularyListScreen> {
  String _query = '';
  String _levelFilter = 'Tất cả';

  static const _levels = ['Tất cả', 'HSK1', 'HSK2', 'HSK3'];

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(wordsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Từ vựng', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26)),
              const SizedBox(height: 6),
              wordsAsync.when(
                data: (words) => Text(
                  '${words.length} từ · HSK 1–3',
                  style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(hintText: 'Tìm từ...'),
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _levels.length; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _levelFilter = _levels[i]),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _levelFilter == _levels[i] ? AppColors.accent : Colors.transparent,
                              border: i > 0 ? const Border(left: BorderSide(color: AppColors.divider)) : null,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            child: Text(
                              _levels[i],
                              style: TextStyle(
                                fontSize: 13,
                                color: _levelFilter == _levels[i] ? AppColors.bg : AppColors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: wordsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Lỗi: $err')),
                  data: (list) {
                    final filtered = _filter(list);
                    if (list.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Chưa có dữ liệu từ vựng.\nThêm assets/data/vocabulary.csv rồi chạy lại app.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (filtered.isEmpty) {
                      return const Center(child: Text('Không tìm thấy từ phù hợp.'));
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final word = filtered[index];
                        return InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => WordDetailScreen(word: word)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.divider)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text(word.simplified, style: const TextStyle(fontSize: 24)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(word.pinyin,
                                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: AppColors.accent700)),
                                      Text(word.meaning, style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
                                    ],
                                  ),
                                ),
                                if (word.hskLevel != null) HskTag(word.hskLevel!),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Word> _filter(List<Word> words) {
    return words.where((w) {
      final matchesLevel = _levelFilter == 'Tất cả' || 'HSK${w.hskLevel}' == _levelFilter;
      if (!matchesLevel) return false;
      if (_query.isEmpty) return true;
      return w.simplified.contains(_query) ||
          w.pinyin.toLowerCase().contains(_query) ||
          w.meaning.toLowerCase().contains(_query);
    }).toList();
  }
}
