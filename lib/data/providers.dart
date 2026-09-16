import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'vocabulary_seed.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final seedProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await seedVocabularyIfEmpty(db);
});

final wordsProvider = StreamProvider<List<Word>>((ref) {
  return ref.watch(databaseProvider).watchWords();
});

final dueCardsProvider = FutureProvider.autoDispose<List<ReviewCard>>((ref) {
  return ref.watch(databaseProvider).dueCards();
});
