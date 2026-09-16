# Tính năng dự kiến triển khai sau

Đã chốt 3 tính năng, thực chất dùng chung một nguồn dữ liệu (bảng `ReviewCards` + `hsk_level` trong `Words`), không cần bài test hay logic đánh giá riêng.

## 1. Đánh giá trình độ hiện tại

Suy ra từ dữ liệu SRS đã có, không làm bài test adaptive riêng.

- Định nghĩa "đã thuộc" một từ: `repetitions >= 3` và `easeFactor` không quá thấp (ví dụ `>= 2.0`).
- Tính % từ "đã thuộc" theo từng `hsk_level`.
- Trình độ hiện tại = HSK level cao nhất có tỷ lệ thuộc đủ cao (ví dụ >= 80%).

## 2. Đặt mục tiêu HSK

- Cho chọn 1 HSK level mục tiêu (lưu vào local, ví dụ `shared_preferences` hoặc 1 bảng `Settings` trong Drift).
- Tính: số từ đã thuộc / tổng số từ thuộc các level <= mục tiêu.
- Hiển thị "còn X từ cần học để đạt HSK N".

## 3. Tiến độ %

- `(số từ đã thuộc / tổng số từ mục tiêu) * 100`, hiển thị progress bar ở màn hình chính.
- Dùng chung dữ liệu và ngưỡng "đã thuộc" như mục 1.

## Việc cần làm khi triển khai

- Thêm query trong `AppDatabase`: đếm từ theo `hsk_level` kèm điều kiện "đã thuộc" (join `Words` + `ReviewCards`).
- Thêm bảng/khoá lưu HSK mục tiêu (Drift table `Settings` hoặc `shared_preferences`).
- 1 provider tổng hợp (`progressProvider`) trả về: trình độ hiện tại, % tiến độ theo mục tiêu, số từ còn thiếu.
- Widget dashboard đơn giản ở `HomeScreen` hoặc màn riêng.

## Ghi chú

- Bài test hàng tuần (quiz theo từ học trong 7 ngày gần nhất) là tính năng **độc lập**, không nằm trong nhóm này — cần logic riêng (chọn từ theo `lastReviewed`, sinh câu hỏi trắc nghiệm, lưu kết quả).

## 4. Tính năng lấy cảm hứng từ app trả phí (Pleco, Du Chinese, HelloChinese...)

Đánh giá theo tỷ lệ giá trị/công sức — ưu tiên làm trước theo thứ tự liệt kê.

### Nên làm — chi phí thấp, giá trị cao

- **Notification nhắc ôn tập hàng ngày** — dùng `flutter_local_notifications`, lên lịch dựa trên số thẻ due hôm nay (đọc từ `dueCards()` đã có).
- **Chế độ nghe (listening mode)** — đảo thứ tự hiển thị trong `ReviewScreen`: phát audio/pinyin trước, người dùng đoán nghĩa/chữ trước khi lật thẻ. Tái dùng UI flashcard hiện có.
- **Tìm kiếm/tra từ điển nhanh** — search bar full-text trên bảng `Words` (đã có sẵn data CC-CEDICT), không cần thêm nguồn dữ liệu mới.
- **Dark mode** — `ThemeMode` của Flutter, gần như miễn phí về công sức.

### Cân nhắc — có giá trị nhưng tốn công thực sự

- **Stroke-order animation** (viết chữ Hán) — dùng `hanzi_writer` qua WebView (đã note ở bản khung ban đầu). Ưu tiên hơn nhận diện chữ viết tay vì ít công hơn nhiều mà vẫn phục vụ mục tiêu luyện viết.
- **Bài học có cấu trúc theo chủ đề** (kiểu Du Chinese) — cần tự soạn nội dung hội thoại/ngữ pháp, không có nguồn mở đủ chất lượng, tốn thời gian nội dung hơn là code.
- **TTS giọng đọc tự nhiên hơn** — `flutter_tts` (giọng hệ thống) đủ dùng ban đầu; có thể nâng cấp bằng Edge TTS sau nếu thấy khó nghe.

### Không nên làm cho app cá nhân

- Chấm điểm phát âm bằng AI (kiểu ELSA) — cần model riêng, không khả thi tự làm chất lượng tốt.
- Nội dung video/hội thoại thực tế — vướng bản quyền, không có nguồn mở tốt.
- Social/leaderboard/bạn học — vô nghĩa với app một người dùng.

## 5. Ôn tập ngữ pháp / cấu trúc câu (không chỉ từ vựng)

Từ vựng không đủ — tiếng Trung có nhiều điểm ngữ pháp (把-sentence, 了 hoàn thành/biến đổi, 比 so sánh...) không suy luận được từ từ đơn lẻ, cần ôn riêng.

### Hướng thiết kế: coi ngữ pháp là một loại "thẻ" trong cùng hệ SRS, không xây module riêng

- Thêm bảng `GrammarPoints` (id, structure, explanation, exampleSentence, hskLevel), song song với `Words`.
- **Thay đổi kiến trúc cần lưu ý**: sửa `ReviewCards` để tham chiếu chung thay vì chỉ trỏ `wordId` — thêm cột `itemType` ('word' | 'grammar') và `itemId`. Nhờ vậy tái dùng nguyên thuật toán SM-2 (`srs.dart`) và `ReviewScreen` đã có, chỉ đổi cách hiển thị mặt trước/sau thẻ tuỳ `itemType`.
- Câu ví dụ (Tatoeba, đã note ở mục tính năng "nên có") gắn tự nhiên vào đây — mỗi điểm ngữ pháp nên có 1-2 câu ví dụ thực tế thay vì chỉ giải thích suông.

### Nguồn dữ liệu

- Không có nguồn mở structured tốt như CC-CEDICT cho ngữ pháp. Phải tự tổng hợp danh sách điểm ngữ pháp theo cấp HSK (nhiều bảng liệt kê công khai trên các trang luyện thi HSK) rồi tự viết giải thích ngắn — nội dung cần tự làm để đảm bảo hiểu đúng, không nên copy máy móc.

## 6. Screen map tổng quan (chi tiết hoá sau trong Claude Design)

### Điều hướng: bottom navigation 4 tab

```
[Tổng quan] [Từ vựng] [Ôn tập] [Ngữ pháp]
```

Settings truy cập qua icon góc trên (không cần tab riêng, ít dùng).

### Chi tiết từng màn hình

1. **Tổng quan (Home/Dashboard)** — màn hình mặc định
   - Progress bar tiến độ theo mục tiêu HSK (mục 2-3)
   - Số thẻ due hôm nay (từ vựng + ngữ pháp) → CTA "Ôn tập ngay"
   - Trình độ hiện tại ước tính (mục 1)
   - Streak ngày học liên tục
2. **Từ vựng** — đã có khung (`vocabulary_list_screen.dart`)
   - Search bar tra từ điển nhanh (mục 4) + filter theo HSK level
   - Tap vào từ → chi tiết (nghĩa, câu ví dụ, phát âm, stroke-order sau này)
3. **Ôn tập** — đã có khung (`review_screen.dart`)
   - Gộp thẻ từ vựng + ngữ pháp (theo `itemType`, mục 5)
   - Toggle chế độ xem chữ trước / nghe trước (listening mode, mục 4)
   - Kết quả buổi ôn sau khi hết thẻ due
4. **Ngữ pháp** — tab mới, cấu trúc tương tự tab Từ vựng
   - Danh sách điểm ngữ pháp theo HSK level, tap vào xem giải thích + câu ví dụ
5. **Kiểm tra hàng tuần** — không cần tab riêng, access từ Tổng quan/notification
   - Trắc nghiệm ngắn từ nội dung học trong 7 ngày qua, lưu % theo tuần
6. **Settings**
   - Đặt mục tiêu HSK, bật/tắt notification nhắc ôn tập, dark mode

### Gợi ý khi thiết kế chi tiết

- 1 màu nhấn theo cấp HSK (gradient xanh→đỏ từ HSK1→HSK6) dùng nhất quán ở Từ vựng/Ngữ pháp/progress bar.
- Flashcard là component tái sử dụng chung cho từ vựng và ngữ pháp (khớp hướng data model ở mục 5) — layout giữ nguyên, chỉ đổi nội dung mặt trước/sau.

## 7. Font đề xuất (tiếng Việt + tiếng Trung)

Ưu tiên **một họ font (Noto)** cho cả hai ngôn ngữ để đảm bảo đồng bộ thị giác, thay vì trộn nhiều font khác nhau:

- **Chữ Latin/tiếng Việt (UI, pinyin, nghĩa)**: `Noto Sans` — hỗ trợ đầy đủ dấu tiếng Việt và dấu thanh pinyin (ā á ǎ à), miễn phí, mã nguồn mở (SIL OFL).
  - Thay thế nếu muốn phong cách "Việt hoá" rõ hơn: `Be Vietnam Pro` (font do người Việt thiết kế, cũng free/open).
- **Chữ Hán**: `Noto Sans SC` (giản thể) — cùng gia đình thiết kế với Noto Sans nên đồng bộ độ đậm/tỷ lệ, tránh lệch phong cách khi hiển thị xen kẽ Hán-Việt trên cùng màn hình.
  - Cỡ chữ lớn (flashcard mặt chữ Hán) có thể cân nhắc `Noto Serif SC` để rõ nét hơn ở kích thước lớn, nhưng nên test thực tế trước khi chốt.
- Cả hai đều có sẵn qua package `google_fonts` trong Flutter, không cần tự bundle file font, tải theo yêu cầu.
- Tránh dùng font quá mảnh (thin weight) cho chữ Hán — nét phức tạp dễ bị mờ/khó đọc trên màn hình nhỏ.
