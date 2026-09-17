import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'grammar_seed.dart';
import 'settings_service.dart';
import 'vocabulary_seed.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final seedProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await seedVocabularyIfEmpty(db);
  await seedGrammarIfEmpty(db);
});

final wordsProvider = StreamProvider<List<Word>>((ref) {
  return ref.watch(databaseProvider).watchWords();
});

final grammarPointsProvider = StreamProvider<List<GrammarPoint>>((ref) {
  return ref.watch(databaseProvider).watchGrammarPoints();
});

final dueCardsProvider = FutureProvider.autoDispose<List<ReviewCard>>((ref) {
  return ref.watch(databaseProvider).dueCards();
});

final recentWordsProvider = FutureProvider.autoDispose<List<Word>>((ref) {
  return ref.watch(databaseProvider).recentlyReviewedWords(3);
});

class ProgressData {
  final int dueToday;
  final int learnedTotal;
  final int streakDays;
  final List<LevelCount> byLevel;
  /// Review counts for the current week, Monday(0) through Sunday(6).
  final List<int> weekCounts;

  const ProgressData({
    required this.dueToday,
    required this.learnedTotal,
    required this.streakDays,
    required this.byLevel,
    required this.weekCounts,
  });
}

final progressProvider = FutureProvider.autoDispose<ProgressData>((ref) async {
  final db = ref.watch(databaseProvider);
  final due = await db.dueCards();
  final learned = await db.learnedWordCount();
  final byLevel = await db.masteredCountsByLevel();
  final dates = await db.reviewLogDates();

  return ProgressData(
    dueToday: due.length,
    learnedTotal: learned,
    streakDays: _computeStreak(dates),
    byLevel: byLevel,
    weekCounts: _computeWeekCounts(dates),
  );
});

int _computeStreak(List<DateTime> reviewedAt) {
  final days = reviewedAt.map(_dateOnly).toSet();
  if (days.isEmpty) return 0;

  var cursor = _dateOnly(DateTime.now());
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
  }

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

List<int> _computeWeekCounts(List<DateTime> reviewedAt) {
  final counts = List<int>.filled(7, 0);
  final now = DateTime.now();
  final monday = _dateOnly(now).subtract(Duration(days: now.weekday - 1));
  for (final ts in reviewedAt) {
    final day = _dateOnly(ts);
    final offset = day.difference(monday).inDays;
    if (offset >= 0 && offset < 7) counts[offset]++;
  }
  return counts;
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

class GoalProgress {
  final String targetLevel;
  final int mastered;
  final int total;
  const GoalProgress({required this.targetLevel, required this.mastered, required this.total});

  double get ratio => total == 0 ? 0 : mastered / total;
  int get percent => (ratio * 100).round();
  int get remaining => total - mastered;
}

/// Mastered/total words across every level up to (and including) the user's
/// target HSK level — the "Mục tiêu HSK" summary shown on Home/Progress.
final goalProgressProvider = FutureProvider.autoDispose<GoalProgress>((ref) async {
  final db = ref.watch(databaseProvider);
  final settings = await ref.watch(settingsProvider.future);
  final targetLevel = int.tryParse(settings.targetHskLevel) ?? 3;
  final byLevel = await db.masteredCountsByLevel();

  var mastered = 0;
  var total = 0;
  for (final level in byLevel) {
    final levelNum = int.tryParse(level.level) ?? 0;
    if (levelNum <= targetLevel) {
      mastered += level.mastered;
      total += level.total;
    }
  }
  return GoalProgress(targetLevel: settings.targetHskLevel, mastered: mastered, total: total);
});

/// Highest HSK level whose mastered ratio clears the threshold — a rough
/// estimate of the user's current level, derived purely from SRS state.
final currentEstimatedLevelProvider = FutureProvider.autoDispose<String>((ref) async {
  final db = ref.watch(databaseProvider);
  final byLevel = await db.masteredCountsByLevel();
  final sorted = [...byLevel]..sort((a, b) => (int.tryParse(a.level) ?? 0).compareTo(int.tryParse(b.level) ?? 0));

  var current = '1';
  for (final level in sorted) {
    if (level.total == 0) continue;
    if (level.mastered / level.total >= 0.8) {
      current = level.level;
    } else {
      break;
    }
  }
  return current;
});
