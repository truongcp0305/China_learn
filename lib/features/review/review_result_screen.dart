import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_card.dart';

/// Shown after the review queue empties — matches mockup screen 10.
class ReviewResultScreen extends StatelessWidget {
  const ReviewResultScreen({
    super.key,
    required this.totalReviewed,
    required this.goodCount,
    required this.wordCount,
    required this.grammarCount,
    required this.streakDays,
  });

  final int totalReviewed;
  final int goodCount;
  final int wordCount;
  final int grammarCount;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'BUỔI ÔN TẬP',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: AppColors.neutral600),
                    ),
                    const SizedBox(height: 10),
                    Text('Hoàn thành!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28)),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: AppCard(
                            kicker: 'Đã ôn',
                            child: _StatValue(value: '$totalReviewed', suffix: 'thẻ'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppCard(
                            kicker: 'Nhớ tốt',
                            child: _StatValue(value: '$goodCount', suffix: '/ $totalReviewed thẻ'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SummaryRow(label: 'Từ vựng', value: '$wordCount thẻ'),
                    _SummaryRow(label: 'Ngữ pháp', value: '$grammarCount thẻ'),
                    const SizedBox(height: 12),
                    _SummaryRow(label: 'Streak', value: '$streakDays ngày liên tiếp'),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Về Tổng quan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.value, required this.suffix});
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
        Text(suffix, style: const TextStyle(fontSize: 13, color: AppColors.neutral800)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
          Text(value, style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
        ],
      ),
    );
  }
}
