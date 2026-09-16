# Chinese Learn (personal project)

Vocabulary + spaced-repetition (SM-2) Chinese learning app. Riverpod for state, Drift (SQLite) for storage.

## 1. Cài Flutter SDK

- Tải Flutter SDK: https://docs.flutter.dev/get-started/install/windows
- Thêm `flutter/bin` vào PATH, sau đó chạy `flutter doctor` và cài các thành phần Android (Android SDK, cmdline-tools, license) mà nó báo thiếu.
- Trên Xiaomi 14T Pro: bật **Developer options → USB debugging**, cắm cáp, chọn "Allow USB debugging" khi máy hỏi. Kiểm tra `flutter devices` thấy máy hiện lên là ổn.

## 2. Sinh thư mục nền tảng (android/, ios/...)

Thư mục này đã có sẵn `pubspec.yaml` và `lib/`, nên **không chạy `flutter create .` trực tiếp ở đây** (nó sẽ đòi ghi đè các file đã viết). Thay vào đó:

```bash
flutter create --org com.yourname --project-name chinese_learn scaffold_tmp
```

Sau đó copy các thư mục nền tảng từ `scaffold_tmp` vào đây rồi xoá `scaffold_tmp`:

```bash
xcopy scaffold_tmp\android android /E /I
xcopy scaffold_tmp\ios ios /E /I
rmdir /S /Q scaffold_tmp
```

(Chỉ cần `android/` nếu bạn không định build iOS.)

## 3. Cài dependency và sinh code Drift

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Lệnh `build_runner` sẽ sinh `lib/data/database.g.dart` (bắt buộc, chưa có file này thì app không build được).

## 4. Nạp dữ liệu từ vựng

App tự đọc `assets/data/vocabulary.csv` (đã khai báo trong `pubspec.yaml`) khi khởi động lần đầu nếu database còn rỗng. Định dạng CSV cần có header:

```csv
simplified,traditional,pinyin,meaning,hsk_level
你好,你好,nǐ hǎo,hello,1
```

Nguồn dữ liệu mở gợi ý:
- **CC-CEDICT** (https://cc-cedict.org) — từ điển Anh-Trung mở, cần tự parse format gốc (`繁體 简体 [pinyin] /nghĩa1/nghĩa2/`) sang CSV trên.
- **HSK vocabulary lists** — tìm "HSK 3.0 vocabulary list csv/json github", nhiều repo đã convert sẵn theo cấp độ.
- **Tatoeba** (https://tatoeba.org) — câu ví dụ song ngữ, dùng cho tính năng sau này (không cần cho bản khung này).

## 5. Chạy app

```bash
flutter run
```

Chọn thiết bị Xiaomi 14T Pro nếu được hỏi.

## Cấu trúc project

```
lib/
  main.dart              # entry point
  app.dart               # MaterialApp
  data/
    database.dart         # Drift schema: Words, ReviewCards
    srs.dart               # thuật toán SM-2 thuần (không phụ thuộc DB/UI)
    vocabulary_seed.dart   # nạp CSV vào DB lần đầu
    providers.dart         # Riverpod providers
  features/
    home/                 # màn hình chính
    vocabulary/           # danh sách từ vựng
    review/               # flashcard ôn tập theo SRS
```

## Việc còn thiếu (chưa làm trong khung này)

- Phát âm (TTS) — package `flutter_tts` đã có trong `pubspec.yaml`, chưa nối vào UI.
- Hiển thị thứ tự nét viết chữ Hán (stroke order) — có thể tích hợp `hanzi_writer` (JS) qua WebView sau.
- Import CC-CEDICT tự động (hiện phải tự convert sang CSV thủ công).
