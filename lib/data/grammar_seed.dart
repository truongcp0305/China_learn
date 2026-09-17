import 'package:drift/drift.dart';

import 'database.dart';

/// Temporary static grammar points (matching the mockup) until the data
/// pipeline's M5 grammar dataset is ready and reviewed. No [ReviewCards] are
/// created here — a card is only made once the user opens the detail screen.
Future<void> seedGrammarIfEmpty(AppDatabase db) async {
  if (await db.grammarPointCount() > 0) return;

  const points = [
    GrammarPointsCompanion(
      code: Value('le'),
      titleZh: Value('了'),
      titleVi: Value('Trợ từ hoàn thành / biến đổi'),
      pattern: Value('S + V + 了'),
      explanationVi: Value(
          'hành động đã xảy ra hoặc trạng thái đã đổi'),
      hskLevel: Value('1'),
      example1Zh: Value('他去了北京。'),
      example1Pinyin: Value('Tā qùle Běijīng.'),
      example1Vi: Value('Anh ấy đã đi Bắc Kinh.'),
    ),
    GrammarPointsCompanion(
      code: Value('bi'),
      titleZh: Value('比'),
      titleVi: Value('Câu so sánh bằng 比'),
      pattern: Value('A 比 B + tính từ'),
      explanationVi: Value('so sánh A hơn B ở một đặc điểm nào đó'),
      hskLevel: Value('2'),
      example1Zh: Value('我比他高。'),
      example1Pinyin: Value('Wǒ bǐ tā gāo.'),
      example1Vi: Value('Tôi cao hơn anh ấy.'),
    ),
    GrammarPointsCompanion(
      code: Value('suiran_danshi'),
      titleZh: Value('虽然…但是'),
      titleVi: Value('Câu nhượng bộ'),
      pattern: Value('虽然 A，但是 B'),
      explanationVi: Value('tuy... nhưng...'),
      hskLevel: Value('2'),
      example1Zh: Value('虽然下雨，但是他还是来了。'),
      example1Pinyin: Value('Suīrán xiàyǔ, dànshì tā háishì láile.'),
      example1Vi: Value('Tuy trời mưa nhưng anh ấy vẫn đến.'),
    ),
    GrammarPointsCompanion(
      code: Value('ba'),
      titleZh: Value('把'),
      titleVi: Value('Câu chữ 把'),
      pattern: Value('S + 把 + O + V + bổ ngữ / kết quả'),
      explanationVi: Value(
          '把 đưa tân ngữ (O) lên trước động từ để nhấn mạnh O được xử lý ra sao. '
          'Câu luôn cần bổ ngữ hoặc thành phần chỉ kết quả sau động từ — không dùng '
          '把 khi câu chỉ có động từ đơn.'),
      hskLevel: Value('3'),
      example1Zh: Value('我把书放在桌子上。'),
      example1Pinyin: Value('Wǒ bǎ shū fàng zài zhuōzi shàng.'),
      example1Vi: Value('Tôi để cuốn sách lên bàn.'),
      example2Zh: Value('他把作业写完了。'),
      example2Pinyin: Value('Tā bǎ zuòyè xiě wán le.'),
      example2Vi: Value('Anh ấy đã viết xong bài tập.'),
    ),
    GrammarPointsCompanion(
      code: Value('bei'),
      titleZh: Value('被'),
      titleVi: Value('Câu bị động bằng 被'),
      pattern: Value('S + 被 + (tác nhân) + V + bổ ngữ / kết quả'),
      explanationVi: Value('chủ ngữ chịu tác động của hành động'),
      hskLevel: Value('3'),
      example1Zh: Value('杯子被他打破了。'),
      example1Pinyin: Value('Bēizi bèi tā dǎ pòle.'),
      example1Vi: Value('Cái cốc đã bị anh ấy làm vỡ.'),
    ),
  ];

  for (final point in points) {
    await db.insertGrammarPoint(point);
  }
}
