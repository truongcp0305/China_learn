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
  TextColumn get hanViet => text().nullable()();
  TextColumn get hskLevel => text().nullable()();
  TextColumn get partOfSpeech => text().nullable()();
  TextColumn get exampleZh => text().nullable()();
  TextColumn get examplePinyin => text().nullable()();
  TextColumn get exampleVi => text().nullable()();
}

/// A grammar point (structure) reviewed the same way as a word — see
/// [ReviewCards.itemType].
class GrammarPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text()();
  TextColumn get titleZh => text()();
  TextColumn get titleVi => text()();
  TextColumn get pattern => text()();
  TextColumn get explanationVi => text()();
  TextColumn get hskLevel => text().nullable()();
  TextColumn get example1Zh => text().nullable()();
  TextColumn get example1Pinyin => text().nullable()();
  TextColumn get example1Vi => text().nullable()();
  TextColumn get example2Zh => text().nullable()();
  TextColumn get example2Pinyin => text().nullable()();
  TextColumn get example2Vi => text().nullable()();
}

const kItemTypeWord = 'word';
const kItemTypeGrammar = 'grammar';

/// A review card for either a word or a grammar point — [itemType] says which
/// table [itemId] points into (no DB-level FK since it targets two tables).
class ReviewCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemType => text()();
  IntColumn get itemId => integer()();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
}

/// One row per graded review — kept separately from [ReviewCards] (which only
/// tracks the latest state per item) so streaks and the weekly chart can be
/// computed from real history instead of the last-overwritten timestamp.
class ReviewLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemType => text()();
  IntColumn get itemId => integer()();
  DateTimeColumn get reviewedAt => dateTime().withDefault(currentDateAndTime)();
}

class LevelCount {
  final String level;
  final int mastered;
  final int total;
  const LevelCount({required this.level, required this.mastered, required this.total});
}

@DriftDatabase(tables: [Words, GrammarPoints, ReviewCards, ReviewLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.deleteTable('review_cards');
            await m.deleteTable('review_log');
            await m.createTable(grammarPoints);
            await m.createTable(reviewCards);
            await m.createTable(reviewLog);
            await m.addColumn(words, words.hanViet);
          }
        },
      );

  Future<int> wordCount() async {
    final rows = await select(words).get();
    return rows.length;
  }

  Stream<List<Word>> watchWords() => select(words).watch();

  Future<int> insertWord(WordsCompanion word) => into(words).insert(word);

  Future<Word> wordById(int id) =>
      (select(words)..where((w) => w.id.equals(id))).getSingle();

  Stream<List<GrammarPoint>> watchGrammarPoints() => select(grammarPoints).watch();

  Future<GrammarPoint> grammarPointById(int id) =>
      (select(grammarPoints)..where((g) => g.id.equals(id))).getSingle();

  Future<int> insertGrammarPoint(GrammarPointsCompanion point) =>
      into(grammarPoints).insert(point);

  Future<int> grammarPointCount() async {
    final rows = await select(grammarPoints).get();
    return rows.length;
  }

  Future<ReviewCard?> reviewCardForItem(String itemType, int itemId) =>
      (select(reviewCards)
            ..where((r) => r.itemType.equals(itemType) & r.itemId.equals(itemId)))
          .getSingleOrNull();

  Future<List<ReviewCard>> dueCards() {
    final now = DateTime.now();
    return (select(reviewCards)..where((r) => r.dueDate.isSmallerOrEqualValue(now)))
        .get();
  }

  Future<void> upsertReviewCard(ReviewCardsCompanion card) =>
      into(reviewCards).insertOnConflictUpdate(card);

  Future<void> ensureReviewCardExists(String itemType, int itemId) async {
    final existing = await reviewCardForItem(itemType, itemId);
    if (existing == null) {
      await into(reviewCards)
          .insert(ReviewCardsCompanion.insert(itemType: itemType, itemId: itemId));
    }
  }

  Future<void> insertReviewLog(String itemType, int itemId) => into(reviewLog)
      .insert(ReviewLogCompanion.insert(itemType: itemType, itemId: itemId));

  /// All review timestamps, most recent first — used to derive the streak
  /// and the "7 ngày qua" chart in the progress provider.
  Future<List<DateTime>> reviewLogDates() async {
    final rows = await (select(reviewLog)
          ..orderBy([(r) => OrderingTerm.desc(r.reviewedAt)]))
        .get();
    return rows.map((r) => r.reviewedAt).toList();
  }

  /// Distinct words most recently reviewed, newest first.
  Future<List<Word>> recentlyReviewedWords(int limit) async {
    final query = select(reviewLog).join([
      innerJoin(
          words, words.id.equalsExp(reviewLog.itemId) & reviewLog.itemType.equals(kItemTypeWord)),
    ])
      ..orderBy([OrderingTerm.desc(reviewLog.reviewedAt)]);
    final rows = await query.get();
    final seen = <int>{};
    final result = <Word>[];
    for (final row in rows) {
      final word = row.readTable(words);
      if (seen.add(word.id)) {
        result.add(word);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  Future<int> learnedWordCount() async {
    final query = selectOnly(reviewCards)
      ..addColumns([reviewCards.itemId])
      ..where(reviewCards.itemType.equals(kItemTypeWord))
      ..where(reviewCards.repetitions.isBiggerOrEqualValue(1));
    final rows = await query.get();
    return rows.length;
  }

  /// Total words and "mastered" words (repetitions >= 3, easeFactor >= 2.0)
  /// grouped by HSK level, for HSK 1-3.
  Future<List<LevelCount>> masteredCountsByLevel() async {
    final result = <LevelCount>[];
    for (final level in ['1', '2', '3']) {
      final totalQuery = selectOnly(words)
        ..addColumns([words.id])
        ..where(words.hskLevel.equals(level));
      final total = (await totalQuery.get()).length;

      final masteredQuery = select(words).join([
        innerJoin(
            reviewCards,
            reviewCards.itemId.equalsExp(words.id) &
                reviewCards.itemType.equals(kItemTypeWord)),
      ])
        ..where(words.hskLevel.equals(level))
        ..where(reviewCards.repetitions.isBiggerOrEqualValue(3))
        ..where(reviewCards.easeFactor.isBiggerOrEqualValue(2.0));
      final mastered = (await masteredQuery.get()).length;

      result.add(LevelCount(level: level, mastered: mastered, total: total));
    }
    return result;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'chinese_learn.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
