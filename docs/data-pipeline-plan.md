# Kế hoạch luồng chuẩn bị dữ liệu HSK

> **Cập nhật 2026-09-16:** M1 (fetch + import-syllabus) và M2 (trang duyệt,
> chưa có LLM) đã triển khai xong ở [`tools/data_pipeline/`](../tools/data_pipeline/README.md).
> Chạy `python -m pipeline.cli fetch/import-syllabus` rồi mở
> `uvicorn server:app` để duyệt. M3 (LLM qua LM Studio) và M4 (xuất gói)
> chưa làm.

Ngày lập: 2026-09-16. Phạm vi: công cụ chạy trên PC để tải nguồn, ghép dữ liệu, soạn nháp bằng luật và LLM cục bộ, duyệt qua web, rồi xuất gói dữ liệu theo cấp cho app mobile. Phía app (tải gói, migration Drift) là kế hoạch riêng.

## 1. Quyết định chính

| Chủ đề | Quyết định | Lý do |
|---|---|---|
| Ngôn ngữ | Python 3.12 + venv | Đã có trên máy, thư viện xử lý dữ liệu tốt |
| Web duyệt | FastAPI + 1 file `index.html` (JS thuần, không build) | Ít phụ thuộc, chạy `uvicorn` là xong |
| DB gốc | SQLite `tools/data_pipeline/data/master.sqlite` | Một file, dễ sao lưu, cùng loại DB với app |
| LLM | LM Studio tại `http://127.0.0.1:1234/v1` (API tương thích OpenAI) | Theo yêu cầu |
| Docker | **Không dùng** ở giai đoạn đầu | LM Studio chạy trên host; container phải gọi qua `host.docker.internal`, thêm phức tạp mà không có lợi. Có thể thêm `Dockerfile` sau nếu cần |
| Mạng | Server chỉ bind `127.0.0.1`. Phục vụ gói qua LAN là tùy chọn bật bằng cờ, chỉ đọc thư mục `dist/` | Tránh lộ API sửa dữ liệu ra mạng |

## 2. Nguồn dữ liệu

Mỗi nguồn được tải về `data/raw/`, ghi lại URL, commit hoặc phiên bản, SHA-256 và ngày tải vào bảng `sources`.

| Nguồn | Dùng cho | Giấy phép |
|---|---|---|
| krmanik/HSK-3.0, thư mục `New HSK (2025)` | Danh sách từ, chữ nhận biết, chữ viết tay, ngữ pháp theo cấp | Trích từ đề cương chính thức; repo ghi nguồn trong `License.md` |
| drkameleon/complete-hsk-vocabulary (`complete.json`) | Pinyin, từ loại, phồn thể, tần suất, nhãn cấp HSK 2.0 | MIT |
| CVDICT (`CVDICT.u8`) | Nghĩa tiếng Việt | CC BY-SA 4.0 |
| CC-CEDICT | Nghĩa tiếng Anh, pinyin dự phòng | CC BY-SA 4.0 |
| evotone/sinov `sino-vietnamese-readings.csv` | Âm Hán Việt ứng viên cho từng chữ | **Repo không khai báo giấy phép** — chỉ dùng cá nhân; cần xin phép hoặc thay nguồn trước khi phát hành |
| Unicode Unihan (`kVietnamese`, `kTraditionalVariant`) | Âm Hán Việt bổ sung, ánh xạ giản thể → phồn thể | Unicode License (cho phép, cần ghi nguồn) |
| pypinyin | Sinh pinyin cho câu ví dụ | MIT |

Kết quả kiểm tra độ phủ âm Hán Việt trên 655 chữ HSK 1–3 (bản 2025):
- Chỉ Unihan: thiếu 101 chữ, nhiều chữ thiếu âm hoặc trả về âm Nôm (ví dụ 们 → "món").
- sinov (tra cả chữ phồn thể qua Unihan): thiếu 25 chữ, ví dụ 们, 她, 吗, 怎, 哪, 您, 做. Các chữ đa âm có đủ ứng viên (行: hành/hàng/hạnh; 长: trường/trưởng).
- Chữ không có ứng viên nào sẽ được đánh dấu để LLM đề xuất và bắt buộc duyệt thủ công.

Yêu cầu ghi nguồn trong app: xem phần 9.

## 3. Cấu trúc thư mục

```
tools/data_pipeline/
  requirements.txt          fastapi, uvicorn, httpx, pypinyin, pytest
  config.toml               URL nguồn, commit ghim, LLM endpoint, batch size
  pipeline/
    db.py                   schema + migration của master.sqlite
    fetch.py                tải nguồn, kiểm SHA-256
    importers/
      syllabus.py           từ, chữ, chữ viết tay, ngữ pháp theo cấp
      dictionaries.py       CVDICT, CC-CEDICT, drkameleon
      hanviet.py            sinov + Unihan
    drafts.py               soạn nháp bằng luật (không LLM)
    llm.py                  client LM Studio, prompt, JSON schema
    validate.py             kiểm tra từ vượt cấp, pinyin, trường bắt buộc
    export.py               xuất gói theo cấp + manifest
    cli.py                  lệnh dòng lệnh cho từng bước
  server.py                 FastAPI: API + phục vụ web/
  web/index.html            giao diện chạy và duyệt
  tests/                    pytest cho parser, luật nháp, validator
  data/raw/                 (gitignore) nguồn đã tải
  data/master.sqlite        (gitignore) DB gốc
  data/backups/             (gitignore) bản sao trước mỗi lần chốt lượt
  data/snapshots/           (commit) dump JSON đã duyệt, để xem diff trong git
  dist/                     (gitignore) gói xuất ra
```

## 4. Schema DB gốc

- `sources(id, name, url, license, revision, sha256, fetched_at)`
- `words(id, simplified, traditional, pinyin, pinyin_numeric, pos, hsk_level, hsk2_level, frequency, meaning_en, meaning_vi, han_viet, example_zh, example_pinyin, example_vi, status, updated_at)`, khóa duy nhất `(simplified, pinyin_numeric)`
- `chars(char, traditional, hsk_level, write_level, han_viet, status)`
- `candidates(id, entity_type, entity_id, field, value, origin, rank)` — mọi giá trị ứng viên từ từ điển và LLM, `origin` thuộc `cvdict | cedict | drkameleon | sinov | unihan | llm | rule`
- `grammar_points(id, level, code, category, title_zh, items, pattern, explanation_vi, examples_json, status)`
- `lessons(id, level, position, title_zh, title_vi, topic)`, `lesson_words(lesson_id, word_id, position)`, `lesson_grammar(lesson_id, grammar_id)` — làm ở mốc M5
- `batches(id, kind, level, size, model, prompt_version, params_json, state, created_at, finalized_at)`
  - `kind`: `meaning_vi | han_viet | example | grammar`
  - `state`: `created → drafting → ready → reviewing → finalized`
- `batch_items(id, batch_id, entity_type, entity_id, draft_json, final_json, warnings_json, llm_raw, error, decision, note, reviewed_at)`
  - `decision`: `pending | approved | edited | rejected | skipped`
- `audit_log(id, entity_type, entity_id, field, old_value, new_value, actor, at)`
- `pack_versions(level, version, content_sha256, file_sha256, counts_json, exported_at)`

Trạng thái mỗi trường nội dung: `missing → auto (luật) → draft (LLM) → approved`. Chỉ `approved` được xuất gói.

## 5. Luồng xử lý

### B1. Tải nguồn — `python -m pipeline.cli fetch`
Tải theo commit đã ghim trong `config.toml`, tính SHA-256, ghi `sources`. Chạy lại không tải trùng nếu hash khớp.

### B2. Nhập đề cương — `cli import-syllabus --level 1`
- Đọc danh sách từ, chữ, chữ viết tay, ngữ pháp của cấp.
- File từ 2025 không có pinyin: tra `complete.json` theo chữ giản thể (mọi cấp), thiếu thì tra CC-CEDICT.
- Từ có nhiều cách đọc (ví dụ 了 le/liǎo, 行 xíng/háng): tạo nhiều ứng viên pinyin, đánh dấu cần chọn. Ưu tiên cách đọc có nhãn HSK trong drkameleon.
- Gắn `hsk2_level` từ nhãn `old-N` của drkameleon.
- In báo cáo: số từ, số chữ, số từ thiếu pinyin, số từ đa âm.

### B3. Ghép từ điển — `cli import-dicts --level 1`
- CVDICT và CC-CEDICT khớp theo `(simplified, pinyin_numeric)`. Mỗi nghĩa thành một ứng viên có thứ tự.
- Báo cáo: số từ không khớp được nghĩa tiếng Việt.

### B4. Ứng viên Hán Việt — `cli import-hanviet --level 1`
- Mỗi chữ: hợp âm từ sinov và Unihan, tra cả chữ phồn thể.
- Âm của từ nhiều chữ = ghép âm từng chữ.

### B5. Nháp bằng luật — `cli draft --level 1`
- `meaning_vi`: lấy tối đa 3 nghĩa đầu của CVDICT, bỏ các mục "biến thể của…", "(Đài Loan)…", "họ …" nếu còn nghĩa khác.
- `han_viet`: tự điền khi mọi chữ chỉ có một ứng viên.
- Mục nào đủ rõ ràng thì `auto`; mục đa âm, thiếu ứng viên hoặc thiếu nghĩa thì để LLM xử lý.

### B6. Soạn nháp bằng LLM — tạo lượt trên web hoặc `cli batch create --kind han_viet --level 1 --size 20`
Client LM Studio:
- Lấy tên model từ `GET /v1/models`, cho chọn trên web.
- `POST /v1/chat/completions` với `response_format: {type: "json_schema", ...}`, `temperature` 0.2, mỗi lần 10–20 mục.
- Timeout và thử lại tối đa 2 lần; lưu nguyên phản hồi vào `llm_raw`.
- Chế độ suy nghĩ của Qwen bật/tắt được trong `config.toml`.
- Mỗi prompt có `prompt_version` lưu vào lượt để truy vết.
- Chạy nền, web theo dõi tiến độ bằng polling; hủy được giữa chừng; chạy lại chỉ xử lý mục lỗi hoặc chưa có nháp.

Nhiệm vụ theo `kind`:
- `han_viet`: đưa từ, pinyin, nghĩa và **danh sách ứng viên từng chữ**; model chỉ được chọn trong danh sách. Chữ không có ứng viên: model đề xuất, gắn cảnh báo `llm_proposed`, bắt buộc sửa hoặc duyệt tay.
- `meaning_vi`: đưa các nghĩa CVDICT và CC-CEDICT; model chọn và rút gọn thành 1–3 nghĩa hợp trình độ HSK. Validator cảnh báo nếu nghĩa không xuất phát từ ứng viên.
- `example`: đưa từ đích và **danh sách từ được phép** (cấp hiện tại và thấp hơn); model trả `example_zh` và `example_vi`. `example_pinyin` sinh bằng pypinyin, không dùng LLM.
- `grammar`: đưa mục ngữ pháp từ đề cương; model soạn mẫu câu, giải thích tiếng Việt và 2 ví dụ trong phạm vi từ được phép.

### B7. Kiểm tra tự động — chạy sau mỗi nháp, kết quả vào `warnings_json`
- Câu ví dụ: tách từ theo khớp dài nhất với danh sách từ HSK; từ vượt cấp hoặc không có trong danh sách → cảnh báo. Câu phải chứa từ đích.
- Hán Việt: số âm bằng số chữ; mỗi âm thuộc ứng viên (trừ `llm_proposed`).
- Nghĩa: không rỗng, không quá dài, không còn tiếng Anh.
- JSON sai schema → mục lỗi, không đưa vào duyệt.

### B8. Duyệt trên web
Xem phần 6. Khi chốt lượt: sao lưu `master.sqlite` vào `data/backups/`, ghi giá trị cuối vào bảng chính với `status = approved`, ghi `audit_log`, cập nhật `data/snapshots/hsk{n}.json`.

### B9. Xuất gói — `cli export --level 1`
- Chỉ lấy mục `approved`. Từ chưa đủ trường bắt buộc (`simplified`, `pinyin`, `meaning_vi`) thì không xuất và liệt kê trong báo cáo; trường tùy chọn (`han_viet`, ví dụ) được phép trống.
- `dist/packs/hsk1.json`: `{schema_version, level, version, generated_at, credits, words[], chars[], grammar[], lessons[]}`.
- `dist/manifest.json`: `{schema_version, packs: [{level, version, file, sha256, size, counts}]}`.
- `version` chỉ tăng khi hash nội dung thay đổi.
- Chạy `validate` trên gói trước khi ghi.

### B10. Phát hành
- Dùng thật: tải `dist/` lên GitHub Releases hoặc host tĩnh, thủ công.
- Thử trên điện thoại: `uvicorn server:app --host 0.0.0.0` với cờ `SERVE_PACKS_ONLY_ON_LAN=1`; khi đó chỉ `/packs/*` và `/manifest.json` mở ra LAN, API duyệt vẫn chỉ nhận yêu cầu từ `127.0.0.1`.

## 6. Web duyệt (`web/index.html`)

Trang đơn, 3 khu:

1. **Tổng quan** theo cấp: số từ/chữ/ngữ pháp theo trạng thái (thiếu, auto, nháp, đã duyệt); nút chạy B2–B5; trạng thái kết nối LM Studio và chọn model.
2. **Lượt**: tạo lượt (cấp, loại, số mục, bộ lọc "chỉ mục thiếu/đa âm/có cảnh báo"); nút chạy LLM; thanh tiến độ; danh sách lượt cũ.
3. **Duyệt lượt**: bảng mỗi dòng một mục
   - Cột: chữ, pinyin, nghĩa CVDICT/CC-CEDICT gốc, ứng viên (chip bấm để chọn), bản nháp (sửa trực tiếp), cảnh báo.
   - Nút mỗi dòng: Duyệt, Từ chối, Sinh lại mục này, Ghi chú.
   - Nút chung: "Duyệt mọi mục không có cảnh báo", "Chốt lượt".
   - Phím tắt: `J/K` chuyển dòng, `A` duyệt, `R` từ chối, `E` sửa, `G` sinh lại.
   - Nút **Xuất gói** và hiển thị diff so với phiên bản gói trước.

API chính: `GET /api/overview`, `POST /api/steps/{step}`, `GET /api/llm/models`, `POST /api/batches`, `POST /api/batches/{id}/run`, `GET /api/batches/{id}`, `PATCH /api/batch-items/{id}`, `POST /api/batches/{id}/finalize`, `POST /api/export/{level}`.

## 7. Mốc triển khai

| Mốc | Nội dung | Kiểm chứng |
|---|---|---|
| M1 | B1–B5 chạy bằng CLI cho HSK1, schema DB, báo cáo độ phủ | pytest cho parser và luật nháp; báo cáo: 300 từ, số mục thiếu nghĩa/Hán Việt |
| M2 | Server + web: tổng quan, tạo lượt, duyệt và chốt **nháp bằng luật** (chưa LLM) | Duyệt được 1 lượt 20 từ, backup và audit log được ghi |
| M3 | LLM: `han_viet`, `meaning_vi`, `example` + validator | Chạy 1 lượt mỗi loại với Qwen 3.5 9B; lỗi JSON được bắt; cảnh báo vượt cấp hoạt động |
| M4 | Xuất gói + manifest + phục vụ LAN | Gói qua `validate`; tải `manifest.json` từ điện thoại trong LAN |
| M5 | Ngữ pháp (`grammar`) và chia bài (giao diện gán từ vào bài) | 15 bài HSK1 có từ và ngữ pháp |
| M6 | Lặp lại cho HSK2, HSK3 | Chỉ đổi tham số `--level` |

Phía app (kế hoạch riêng, sau M4): Drift schemaVersion 2, màn hình tải gói theo cấp, nạp gói theo phiên bản giữ tiến độ học, thẻ ôn chỉ tạo khi học bài, màn hình ghi nguồn.

## 8. Rủi ro

- **sinov không có giấy phép**: dùng cá nhân được; trước khi phát hành phải xin phép tác giả hoặc thay nguồn và rà lại âm Hán Việt.
- **Qwen 9B viết câu sai ngữ pháp**: validator chỉ bắt được từ vượt cấp, không bắt được lỗi ngữ pháp; vẫn cần duyệt kỹ.
- **Pinyin đa âm chọn sai** làm ghép nhầm nghĩa: mục đa âm luôn phải duyệt.
- **Mất công duyệt**: có backup trước mỗi lần chốt và snapshot JSON trong git.
- **Đề cương 2025 có thể được CTI sửa**: nguồn ghim theo commit; khi cập nhật, B2 báo từ thêm/bớt, không xóa mục đã duyệt.

## 9. Ghi nguồn bắt buộc trong app

Màn hình Cài đặt → Giới thiệu và trường `credits` trong mỗi gói phải có:
- CVDICT — Phong Phan — https://github.com/ph0ngp/CVDICT — CC BY-SA 4.0
- CC-CEDICT — MDBG — https://www.mdbg.net/chinese/dictionary?page=cc-cedict — CC BY-SA 4.0
- Ghi rõ dữ liệu từ vựng của app được phái sinh từ hai nguồn trên và chia sẻ theo CC BY-SA 4.0.
- complete-hsk-vocabulary (MIT), Unicode Unihan (Unicode License), sinov (tình trạng giấy phép như mục 8), danh sách đề cương HSK 3.0 (krmanik/HSK-3.0).
