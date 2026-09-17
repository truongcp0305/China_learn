# Kế hoạch tính năng app (sau khi có dữ liệu từ data pipeline)

Ngày lập: 2026-09-17. Bối cảnh: [`tools/data_pipeline/`](../tools/data_pipeline/README.md)
đã xuất được `dist/packs/hsk{1,2,3}.json` — từ có pos/nghĩa/Hán Việt/ví dụ,
chữ Hán riêng có Hán Việt + cờ "phải viết tay", và chỗ trống sẵn cho ngữ
pháp + chia bài (M5, chưa có dữ liệu). Tài liệu này lên kế hoạch app Flutter
dùng dữ liệu đó thế nào — chưa viết code.

## 1. App hiện có gì (đọc trực tiếp từ code, không đoán)

- **DB** ([`lib/data/database.dart`](../lib/data/database.dart)): 3 bảng —
  `Words` (simplified/traditional/pinyin/meaning/hskLevel/partOfSpeech/
  exampleZh/examplePinyin/exampleVi), `ReviewCards` (SM-2: easeFactor/
  intervalDays/repetitions/dueDate), `ReviewLog`. `schemaVersion = 1`,
  **chưa có migration nào** (không cần vì chưa release).
- **Dữ liệu nạp**: [`vocabulary_seed.dart`](../lib/data/vocabulary_seed.dart)
  đọc `assets/data/vocabulary.csv` **một lần khi DB rỗng**, hiện chỉ có 67
  từ, cột ví dụ trống, `exampleZh/Pinyin/Vi` toàn `null`.
- **Màn hình đã có**: Onboarding (chọn cấp HSK + mục tiêu/ngày) → Home
  (streak, số thẻ đến hạn, từ ôn gần đây) → Ôn tập (lật thẻ, 4 nút SM-2
  Quên/Khó/Tốt/Dễ) → Danh sách từ vựng → Chi tiết từ (TTS, ví dụ nếu có) →
  Tiến độ (streak, % thuộc theo cấp, biểu đồ tuần) → Cài đặt (cấp HSK, mục
  tiêu/ngày, theme, giờ nhắc).
- **Dịch vụ**: `flutter_tts` (đọc từ), `flutter_local_notifications` (nhắc
  hằng ngày), `shared_preferences` (settings).
- **Lỗ hổng đã biết** (từ các lượt trước): `masteredCountsByLevel()` viết
  cứng `['1','2','3']`; nạp dữ liệu tạo `ReviewCards` cho **mọi từ ngay lập
  tức** thay vì theo bài học.

Nói ngắn: khung app đã đủ dùng (onboarding → học → ôn → tiến độ → cài đặt),
nhưng dữ liệu quá mỏng (67 từ phẳng, không ví dụ, không Hán Việt, không bài
học) nên nhiều màn hình đang hiển thị rỗng hoặc lặp lại. Việc chính của giai
đoạn tới là **đổ dữ liệu giàu vào đúng chỗ** và **thêm màn hình mà dữ liệu
mới cho phép** — không phải viết lại từ đầu.

## 2. Việc nền tảng bắt buộc trước mọi tính năng mới

### 2.1 Nâng schema DB (`schemaVersion` 1 → 2)

Thêm vào `Words`: `meaningVi` (đổi tên `meaning` cho rõ, hoặc giữ nguyên và
thêm cột), `hanViet`, `hsk2Level`, `frequency`. Bảng mới: `Chars` (char,
traditional, hskLevel, writeLevel, hanViet), `Lessons` (level, position,
titleZh, titleVi, topic), `LessonWords` (lessonId, wordId, position),
`GrammarPoints` (level, code, titleZh, pattern, explanationVi, examples),
`LessonGrammar`. Khớp 1:1 với schema đã có sẵn trong DB gốc của pipeline
(`tools/data_pipeline/pipeline/db.py`) và với JSON pack đã xuất — không cần
thiết kế lại, chỉ cần map sang Drift.

Viết `MigrationStrategy.onUpgrade` giữ nguyên `ReviewCards`/`ReviewLog`;
`Words` cũ (67 dòng CSV) bị thay hẳn bằng dữ liệu từ gói mới nên xóa-nạp lại
là chấp nhận được ở bước này (app chưa phát hành, chưa có người dùng thật
ngoài bạn).

### 2.2 Dịch vụ tải gói (thay thế `vocabulary_seed.dart`)

- `PackSyncService`: tải `manifest.json` từ URL cấu hình (mặc định trỏ
  GitHub Releases sau này; lúc phát triển trỏ thẳng
  `http://<ip-PC-trong-LAN>:8765/manifest.json` — server pipeline đã bật
  sẵn cờ `serve_packs_on_lan`, xem README pipeline).
- So `version` từng cấp với bản đã lưu (`SettingsService` thêm
  `Map<String,int> packVersions`). Cấp có version mới hơn → tải
  `packs/hsk{n}.json`, kiểm `sha256`, rồi nạp vào DB.
- **Nạp theo kiểu merge, không xóa tiến độ**: khớp từ theo
  `(simplified, pinyin)`, `INSERT OR UPDATE` nội dung từ/chữ/bài/ngữ pháp,
  **không đụng** `ReviewCards`/`ReviewLog`. Đúng như đã ghi trong
  [data-pipeline-plan.md §7](data-pipeline-plan.md).
- Chạy nền lúc mở app (giống `seedProvider` hiện tại), có màn hình nhỏ báo
  "đang cập nhật từ vựng…" nếu lần đầu hoặc có bản mới.
- Ngoại tuyến: nếu không tải được và DB đã có dữ liệu cũ, dùng tạm, không
  chặn app.

### 2.3 Sửa việc tạo thẻ ôn hàng loạt

Thẻ `ReviewCards` chỉ được tạo khi từ đó **được học trong một bài** (xem
§3.1), không tạo sẵn cho toàn bộ 300+ từ lúc nạp dữ liệu — nếu không, người
dùng mở app lần đầu sẽ thấy vài trăm thẻ "đến hạn" ngay ngày đầu.

## 3. Tính năng theo giai đoạn

### Giai đoạn A — Học theo bài (thay vì danh sách từ phẳng)

Dữ liệu `lessons`/`grammar` chưa có (M5 pipeline), nhưng nên **thiết kế app
theo cấu trúc bài ngay từ đầu** để không phải viết lại màn hình Home/Học khi
M5 xong.

1. **Màn hình lộ trình** (thay hoặc bổ sung cho Home): danh sách 15 bài mỗi
   cấp, bài sau khoá đến khi bài trước đạt ngưỡng (vd. ≥80% từ đã ôn qua 1
   lần). Icon trạng thái: chưa mở / đang học / xong.
2. **Luồng học 1 bài** (màn hình mới, `lesson_screen.dart`):
   - Bước 1 — Giới thiệu từ mới: lật từng thẻ, có TTS, hiện Hán Việt +
     nghĩa + ví dụ (dữ liệu đã có sẵn từ Giai đoạn nền tảng).
   - Bước 2 — Ngữ pháp: hiện mẫu câu + giải thích tiếng Việt (chờ M5).
   - Bước 3 — Bài tập ngắn: trắc nghiệm nghĩa, nghe-chọn-nghĩa, xếp câu
     (xem Giai đoạn B).
   - Bước 4 — Chốt bài: từ trong bài được `ensureReviewCardExists()` —
     đúng lúc này thẻ ôn mới được tạo (không phải lúc nạp dữ liệu).
3. Cài đặt: giới hạn số từ mới/ngày (đã có `dailyGoal` trong
   `AppSettings`, chỉ cần dùng nó để giới hạn số bài/từ mới thay vì chỉ
   hiển thị số liệu).

### Giai đoạn B — Đa dạng kiểu bài ôn (review card hiện chỉ có lật thẻ)

`review_screen.dart` hiện chỉ có 1 kiểu (chữ Hán → lật ra pinyin+nghĩa).
Thêm kiểu bài xen kẽ theo ngẫu nhiên hoặc theo `repetitions` của từ (từ mới
học nên gặp dạng dễ trước, từ ôn nhiều lần gặp dạng khó hơn — giống cách
HelloChinese/SuperChinese làm):

- **Nhận diện** (đang có): Hán → lật xem pinyin/nghĩa.
- **Trắc nghiệm nghĩa**: hiện chữ Hán, chọn 1/4 nghĩa (nhiễu lấy từ các từ
  cùng cấp khác — dữ liệu `meaning_vi` đã đủ để tạo nhiễu tự động).
  Giấy tờ tương đương: gần với dạng đọc hiểu HSK thật, HSK1 chỉ thi nghe+đọc.
- **Nghe - chọn nghĩa**: TTS đọc, chọn nghĩa/chữ đúng.
- **Chọn thanh điệu / pinyin**: hiện chữ, chọn đúng pinyin trong 4 lựa
  chọn (nhiễu lấy từ candidate pinyin đa âm đã có sẵn trong pipeline).
- **Điền từ vào câu ví dụ**: dùng `example_zh`/`example_vi` đã có, ẩn từ
  đích trong câu, chọn hoặc gõ lại — cần `example_zh` được duyệt trước
  (M3 đã chạy được, đang chờ bạn duyệt).

Kiến trúc: tách `ReviewCardWidget` hiện tại thành nhiều `ReviewExerciseType`
(1 file/loại dưới `lib/features/review/exercises/`), `review_screen.dart`
chỉ điều phối hàng đợi + chọn loại bài, chấm điểm SM-2 vẫn dùng
`calculateNextReview()` sẵn có không đổi.

### Giai đoạn C — Hán Việt & chữ Hán hiển thị khắp nơi

Có sẵn dữ liệu, chỉ là việc UI:

- `word_detail_screen.dart`: thêm dòng Hán Việt cạnh pinyin (giúp nhớ theo
  kiểu người Việt quen thuộc).
- `vocabulary_list_screen.dart`: thêm cột/nhãn Hán Việt, lọc theo từ loại
  (`pos`), lọc theo cấp 2.0 hay 3.0 (`hsk2_level` vs `hsk_level`).
- Màn hình mới **Danh sách chữ Hán** (khác từ vựng — chữ đơn lẻ, ví dụ 爱
  xuất hiện trong nhiều từ): hiện Hán Việt riêng của chữ, đánh dấu chữ nào
  "phải viết tay" theo `write_level` — chuẩn bị cho Giai đoạn E (luyện
  viết).

### Giai đoạn D — Ngữ pháp + lên cấp HSK2/HSK3

- Màn hình **Ngữ pháp** trong mỗi bài (mẫu câu + giải thích tiếng Việt +
  2 ví dụ) — chờ dữ liệu M5.
- Onboarding/Cài đặt: `hskLevel` hiện chỉ là String lưu sẵn, thêm UI chọn
  lộ trình HSK1→2→3 nối tiếp (khoá cấp sau đến khi cấp trước đạt ngưỡng,
  giống khoá bài trong 1 cấp).
- `progress_screen.dart`: sửa `masteredCountsByLevel()` đọc cấp có thật
  trong DB thay vì hard-code `['1','2','3']` (đã ghi ở §1), thêm "sẵn sàng
  thi HSK{n}" dựa trên % từ + ngữ pháp đã thuộc so với đề cương.

### Giai đoạn E — Luyện viết chữ Hán (sau, cần thêm nguồn dữ liệu)

Dữ liệu nét chữ **chưa có** trong pipeline hiện tại. Cần thêm nguồn (vd.
Make Me a Hanzi — cần kiểm giấy phép trước khi dùng, ghi trong
data-pipeline-plan.md §3 giai đoạn 4) rồi mới làm được:

- Màn hình viết theo thứ tự nét cho các chữ có `write_level` ≤ cấp đang học.
- Chấm bằng so khớp nét vẽ (thư viện Flutter vẽ tay + so sánh path), không
  cần AI nhận diện chữ viết tay phức tạp ở bản đầu.

### Giai đoạn F — Hoàn thiện

- Đề thi thử HSK theo cấp (nghe+đọc, đúng cấu trúc đề thật).
- Màn hình **Giới thiệu/Nguồn dữ liệu** trong Cài đặt: ghi credit CVDICT +
  CC-CEDICT (CC BY-SA 4.0) + các nguồn khác — bắt buộc, đã ghi trong memory
  `data-license-credit`.
- Thay TTS máy bằng file mp3 có sẵn trong `krmanik/HSK-3.0` (chất lượng âm
  thật hơn giọng tổng hợp).
- Widget màn hình khoá/thông báo nhắc học kèm số từ đến hạn (mở rộng
  `notification_service.dart` hiện đã có nhắc giờ cố định).

## 4. Thứ tự đề xuất

1. **Nâng schema + PackSyncService** (§2) — bắt buộc, mọi thứ khác phụ
   thuộc vào đây. Có thể làm ngay với dữ liệu HSK1 hiện có (chưa cần chờ
   M5 ngữ pháp).
2. **Giai đoạn C** (Hán Việt/chữ Hán hiển thị) — ít việc, thấy hiệu quả
   ngay, không cần màn hình mới.
3. **Giai đoạn A** (học theo bài) — thay đổi kiến trúc Home lớn nhất, nên
   làm sớm để các giai đoạn sau (B, D) gắn vào đúng chỗ.
4. **Giai đoạn B** (đa dạng bài ôn) — giá trị học tập cao nhất, độc lập
   với A về mặt kỹ thuật (có thể làm song song).
5. **Giai đoạn D** (ngữ pháp + HSK2/3) — chờ M5 pipeline có dữ liệu ngữ
   pháp thật.
6. **Giai đoạn E, F** — sau cùng, không chặn việc dùng app hằng ngày.

## 5. Quyết định cần bạn xác nhận trước khi code

- **Giữ tên cột `meaning` hay đổi sang `meaningVi`?** Đổi tên rõ nghĩa hơn
  nhưng động vào mọi màn hình đang dùng `word.meaning`; giữ nguyên thì đỡ
  sửa nhưng dễ nhầm khi sau này có thêm `meaningEn`.
- **Học theo bài có bắt buộc ngay không**, hay trước mắt cứ đổ 300 từ HSK1
  vào danh sách phẳng như hiện tại (nhanh hơn nhiều) rồi làm Giai đoạn A
  sau? Nếu ưu tiên có cái dùng được sớm, nên làm bước 1+2 trước, hoãn bài
  học (A) lại.
- **Nguồn nét chữ cho luyện viết** (Giai đoạn E) chưa chọn — cần tôi tìm
  và kiểm giấy phép trước không?
