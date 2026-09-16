import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Words extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get simplified => text()();
  TextColumn get traditional => text().nullable()();
  TextColumn get pinyin => text()();
  TextColumn get meaning => text()();
  TextColumn get hskLevel => text().nullable()();
}

class ReviewCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wordId => integer().references(Words, #id)();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
}

@DriftDatabase(tables: [Words, ReviewCards])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> wordCount() async {
    final rows = await select(words).get();
    return rows.length;
  }

  Stream<List<Word>> watchWords() => select(words).watch();

  Future<int> insertWord(WordsCompanion word) => into(words).insert(word);

  Future<Word> wordById(int id) =>
      (select(words)..where((w) => w.id.equals(id))).getSingle();

  Future<ReviewCard?> reviewCardForWord(int wordId) =>
      (select(reviewCards)..where((r) => r.wordId.equals(wordId)))
          .getSingleOrNull();

  Future<List<ReviewCard>> dueCards() {
    final now = DateTime.now();
    return (select(reviewCards)..where((r) => r.dueDate.isSmallerOrEqualValue(now)))
        .get();
  }

  Future<void> upsertReviewCard(ReviewCardsCompanion card) =>
      into(reviewCards).insertOnConflictUpdate(card);

  Future<void> ensureReviewCardExists(int wordId) async {
    final existing = await reviewCardForWord(wordId);
    if (existing == null) {
      await into(reviewCards).insert(ReviewCardsCompanion.insert(wordId: wordId));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'chinese_learn.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
