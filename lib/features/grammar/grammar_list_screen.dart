import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../theme.dart';
import '../../widgets/hsk_tag.dart';
import 'grammar_detail_screen.dart';

class GrammarListScreen extends ConsumerStatefulWidget {
  const GrammarListScreen({super.key});

  @override
  ConsumerState<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends ConsumerState<GrammarListScreen> {
  String _levelFilter = 'Tất cả';

  static const _levels = ['Tất cả', 'HSK1', 'HSK2', 'HSK3'];

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(grammarPointsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ngữ pháp', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26)),
              const SizedBox(height: 6),
              pointsAsync.when(
                data: (points) => Text(
                  '${points.length} điểm ngữ pháp · HSK 1–3',
                  style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),
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
                child: pointsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Lỗi: $err')),
                  data: (list) {
                    final filtered = _filter(list);
                    if (filtered.isEmpty) {
                      return const Center(child: Text('Không tìm thấy điểm ngữ pháp phù hợp.'));
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final point = filtered[index];
                        return InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => GrammarDetailScreen(point: point)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.divider)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 56,
                                  child: Text(point.titleZh, style: const TextStyle(fontSize: 20)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(point.titleVi, style: const TextStyle(fontSize: 14)),
                                      Text(point.explanationVi,
                                          style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (point.hskLevel != null) HskTag(point.hskLevel!),
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

  List<GrammarPoint> _filter(List<GrammarPoint> points) {
    if (_levelFilter == 'Tất cả') return points;
    return points.where((p) => 'HSK${p.hskLevel}' == _levelFilter).toList();
  }
}
