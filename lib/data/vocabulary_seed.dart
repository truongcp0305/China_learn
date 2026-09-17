import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'database.dart';

/// Loads assets/data/vocabulary.csv (columns: simplified,traditional,pinyin,meaning,hsk_level,
/// then optional part_of_speech,example_zh,example_pinyin,example_vi)
/// into the database the first time the app runs. Safe to call repeatedly.
Future<void> seedVocabularyIfEmpty(AppDatabase db) async {
  if (await db.wordCount() > 0) return;

  final String raw;
  try {
    raw = await rootBundle.loadString('assets/data/vocabulary.csv');
  } catch (_) {
    // No bundled dataset yet — see README for where to get one (CC-CEDICT / HSK lists).
    return;
  }

  final rows = const CsvToListConverter(eol: '\n').convert(raw, shouldParseNumbers: false);
  final dataRows = rows.isNotEmpty && rows.first.first.toString().toLowerCase() == 'simplified'
      ? rows.skip(1)
      : rows;

  for (final row in dataRows) {
    if (row.length < 4) continue;
    String? cell(int index) {
      if (index >= row.length) return null;
      final value = row[index].toString();
      return value.isEmpty ? null : value;
    }

    final wordId = await db.insertWord(WordsCompanion.insert(
      simplified: row[0].toString(),
      pinyin: row[2].toString(),
      meaning: row[3].toString(),
      traditional: Value(cell(1)),
      hskLevel: Value(cell(4)),
      partOfSpeech: Value(cell(5)),
      exampleZh: Value(cell(6)),
      examplePinyin: Value(cell(7)),
      exampleVi: Value(cell(8)),
    ));
    await db.ensureReviewCardExists(kItemTypeWord, wordId);
  }
}
