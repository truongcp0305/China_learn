/// SM-2 spaced-repetition algorithm.
/// `quality` is a 0-5 self-rating of recall (< 3 counts as a lapse).
class SrsResult {
  final double easeFactor;
  final int intervalDays;
  final int repetitions;

  const SrsResult({
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
  });
}

SrsResult calculateNextReview({
  required double easeFactor,
  required int intervalDays,
  required int repetitions,
  required int quality,
}) {
  if (quality < 3) {
    return SrsResult(easeFactor: easeFactor, intervalDays: 1, repetitions: 0);
  }

  final newEase =
      (easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
          .clamp(1.3, 25.0);

  final int newInterval;
  if (repetitions == 0) {
    newInterval = 1;
  } else if (repetitions == 1) {
    newInterval = 6;
  } else {
    newInterval = (intervalDays * newEase).round();
  }

  return SrsResult(
    easeFactor: newEase,
    intervalDays: newInterval,
    repetitions: repetitions + 1,
  );
}
