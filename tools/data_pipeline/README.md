# HSK data pipeline

Chuẩn bị dữ liệu từ vựng/chữ Hán/Hán Việt cho app, theo kế hoạch ở
[`docs/data-pipeline-plan.md`](../../docs/data-pipeline-plan.md). Chạy trên
máy này (PC), không chạy trong app.

## Cài đặt (một lần)

```bash
cd tools/data_pipeline
python -m venv .venv
./.venv/Scripts/python -m pip install -r requirements.txt
```

## Chạy

```bash
# 1. Tải nguồn (đề cương HSK 2025, complete-hsk-vocabulary, CVDICT, CC-CEDICT, sinov, Unihan)
./.venv/Scripts/python -m pipeline.cli fetch --levels 1,2,3

# 2. Ghép thành từ + chữ + ứng viên Hán Việt/nghĩa cho từng cấp
./.venv/Scripts/python -m pipeline.cli import-syllabus --levels 1,2,3

# 3. Xem số liệu bao phủ
./.venv/Scripts/python -m pipeline.cli overview

# 4. Mở trang duyệt
./.venv/Scripts/python -m uvicorn server:app --host 127.0.0.1 --port 8765
# rồi mở http://127.0.0.1:8765
```

Chạy lại `fetch`/`import-syllabus` là an toàn: dữ liệu đã `approved` hoặc
đang `draft` không bao giờ bị ghi đè, chỉ các trường còn `missing`/`auto`
được cập nhật lại.

## Test

```bash
./.venv/Scripts/python -m pytest tests/ -q
```

## Chạy LLM (LM Studio)

Mở LM Studio, load một model (đã thử với `qwen/qwen3.5-9b`), bật server ở
`http://127.0.0.1:1234`. Trên trang duyệt, mục "LM Studio" tự kiểm tra kết
nối; chọn loại (nghĩa/Hán Việt từ/Hán Việt chữ/ví dụ), cấp, số lượng rồi bấm
"Chạy LLM". Kết quả ghi thẳng vào `words`/`chars` ở trạng thái `draft` —
**vẫn phải duyệt tay**, model 9B có thể sai (đã thấy 姐→"tả" sai, đúng phải
là "tỷ"; 饭→"phãn" sai chính tả). Mỗi lượt chạy được ghi vào bảng `batches`/
`batch_items` để tra lại; cảnh báo tự động (từ vượt cấp, số âm không khớp số
chữ, nghĩa còn sót tiếng Anh) hiện ngay trong bảng duyệt.

## Xuất gói cho app (M4)

```bash
./.venv/Scripts/python -m pipeline.cli export --levels 1,2,3
```

hoặc bấm "Xuất dist/packs + manifest.json" trên web. Ghi ra
`dist/packs/hsk{n}.json` + `dist/manifest.json`. Chỉ dữ liệu đã `approved`
(hoặc `edited`) được xuất — trường nào chưa duyệt thì cả từ đó bị bỏ khỏi
gói (bắt buộc: pinyin + nghĩa) hoặc chỉ bỏ riêng trường đó (Hán Việt/ví dụ,
không bắt buộc). Chạy lại an toàn: `version` chỉ tăng khi nội dung thật sự
đổi.

Xem thử qua HTTP: `http://127.0.0.1:8765/manifest.json`,
`http://127.0.0.1:8765/packs/hsk1.json`.

Cho điện thoại tải qua LAN: đặt `serve_packs_on_lan = true` trong
`config.toml`, chạy `uvicorn server:app --host 0.0.0.0 --port 8765`. Khi đó
mọi máy trong LAN chỉ truy cập được `/manifest.json` và `/packs/*`; API duyệt
(sửa dữ liệu) bị chặn với máy không phải `127.0.0.1`.

## Trạng thái (2026-09-17)

- **Xong (M1):** tải nguồn ghim theo commit, ghép từ + chữ theo cấp, ứng
  viên nghĩa (CVDICT/CC-CEDICT) và Hán Việt (sinov + Unihan).
- **Xong (M2):** trang web duyệt (`web/index.html`) cho nghĩa/Hán Việt/ví dụ
  của từ và Hán Việt của chữ.
- **Xong (M3):** `pipeline/llm.py` (client LM Studio, `response_format:
  json_schema`), `pipeline/prompts.py`, `pipeline/batches.py` (chọn mục cần
  xử lý, gọi theo lô 12, ghi draft + cảnh báo), `pipeline/validate.py`
  (kiểm tra tự động). Nút "Chạy LLM" trên web đã chạy thật, đã kiểm tra 4
  loại (nghĩa/Hán Việt từ/Hán Việt chữ/ví dụ).
- **Xong (M4):** `pipeline/export.py` xuất `dist/packs/hsk{n}.json` +
  `dist/manifest.json` từ dữ liệu đã duyệt, versioning theo hash nội dung,
  phục vụ qua `/manifest.json` + `/packs/*`, giới hạn LAN chỉ cho hai route
  đó khi `serve_packs_on_lan=true`. Nút "Xuất gói" trên web đã chạy thật.
- **Chưa làm:** ngữ pháp + chia bài (M5 — schema `grammar_points`/`lessons`
  đã có sẵn trong DB và trong export, chỉ chưa có importer/UI điền dữ liệu),
  lặp lại cho HSK2/3 (M6 — M1-M4 đã chạy sẵn cho cả 3 cấp, chỉ còn duyệt nội
  dung), phần app Flutter tải gói (kế hoạch riêng, sau M4).

## Lưu ý giấy phép dữ liệu

- CVDICT, CC-CEDICT: CC BY-SA 4.0 — **phải ghi nguồn trong app** (xem
  memory `data-license-credit`).
- complete-hsk-vocabulary: MIT.
- Unicode Unihan: Unicode License, cần ghi nguồn.
- evotone/sinov: **repo không khai báo giấy phép.** Dùng cá nhân được; nếu
  phát hành app phải xin phép tác giả hoặc thay nguồn Hán Việt khác trước.
- Đề cương HSK 3.0 (krmanik/HSK-3.0): trích từ đề cương chính thức MOE/CTI.

## Cấu trúc

```
pipeline/
  config.py, db.py, fetch.py, repo.py, cli.py
  importers/dictionaries.py   parser CVDICT / CC-CEDICT / complete.json
  importers/hanviet.py        ứng viên Hán Việt (sinov + Unihan)
  importers/syllabus.py       ghép từ/chữ theo cấp, chọn nghĩa/reading chính
server.py                     FastAPI, phục vụ web/ và API duyệt
web/index.html                trang duyệt (không cần build)
data/raw/                     nguồn đã tải (gitignore)
data/master.sqlite            DB gốc (gitignore)
```
