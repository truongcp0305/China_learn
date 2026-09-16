import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class VocabularyListScreen extends ConsumerWidget {
  const VocabularyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(wordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Từ vựng')),
      body: words.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có dữ liệu từ vựng.\n'
                  'Thêm assets/data/vocabulary.csv rồi chạy lại app.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final word = list[index];
              return ListTile(
                title: Text('${word.simplified}  ${word.pinyin}'),
                subtitle: Text(word.meaning),
                trailing: word.hskLevel != null ? Text(word.hskLevel!) : null,
              );
            },
          );
        },
      ),
    );
  }
}
