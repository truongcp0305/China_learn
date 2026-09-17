"""Prompt + JSON schema builders per batch kind (plan section 5, B6).

Kept deliberately small: we never hand the model a task it can freely
improvise — han_viet must pick from a fixed candidate list, meaning_vi must
pick/trim from dictionary candidates, and example sentences are checked
against the allowed-vocabulary list afterwards by validate.py rather than
enumerated in the prompt (which would blow up token cost at HSK3's 500+
words). `prompt_version` is bumped whenever the wording changes meaningfully,
so a batch's `batches.prompt_version` column stays a useful audit trail.
"""
from __future__ import annotations

PROMPT_VERSION = "1"

_SYSTEM_COMMON = (
    "Bạn là biên tập từ điển Hán-Việt cho app tự học tiếng Trung HSK của một "
    "người Việt. Trả lời đúng theo schema JSON, giữ nguyên field 'id' của "
    "từng mục, không thêm mục, không bỏ mục, không thêm chữ thừa ngoài JSON."
)


def build_meaning_prompt(level: int, items: list[dict]) -> tuple[str, str, str, dict]:
    """items: [{id, simplified, pinyin, meaning_en, candidates: [str, ...]}]"""
    system = (
        _SYSTEM_COMMON
        + f" Nhiệm vụ: với mỗi từ HSK{level}, chọn và rút gọn thành 1-2 nghĩa tiếng Việt "
        "ngắn gọn, tự nhiên, đúng với cách dùng phổ biến nhất ở trình độ này. "
        "Chỉ dùng thông tin từ 'candidates' (nghĩa gốc tiếng Việt/tiếng Anh) đã cho, "
        "không tự bịa nghĩa khác. Bỏ qua các nghĩa kiểu 'họ...', 'biến thể của...' "
        "trừ khi không còn nghĩa nào khác."
    )
    lines = [
        f"{i['id']}. {i['simplified']} [{i['pinyin']}] candidates={i['candidates']}"
        for i in items
    ]
    user = "Danh sách từ:\n" + "\n".join(lines)
    schema = {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {"id": {"type": "integer"}, "meaning_vi": {"type": "string"}},
                    "required": ["id", "meaning_vi"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["items"],
        "additionalProperties": False,
    }
    return system, user, "meaning_batch", schema


def build_han_viet_word_prompt(level: int, items: list[dict]) -> tuple[str, str, str, dict]:
    """items: [{id, simplified, pinyin, meaning_vi, char_candidates: {char: [str,...]}}]"""
    system = (
        _SYSTEM_COMMON
        + " Nhiệm vụ: với mỗi từ tiếng Trung gồm nhiều chữ Hán, ghép âm Hán Việt của "
        "cả từ bằng cách CHỌN đúng một âm cho MỖI chữ trong danh sách ứng viên "
        "'char_candidates' của chữ đó (không tự nghĩ ra âm ngoài danh sách, trừ khi "
        "danh sách của chữ đó rỗng — khi đó hãy đề xuất âm Hán Việt hợp lý nhất và "
        "đặt need_review=true). Trả về chuỗi Hán Việt cách nhau bằng dấu cách, đúng "
        "thứ tự chữ trong từ."
    )
    lines = []
    for i in items:
        cc = ", ".join(f"{ch}:{cands}" for ch, cands in i["char_candidates"].items())
        lines.append(f"{i['id']}. {i['simplified']} [{i['pinyin']}] nghĩa={i['meaning_vi']!r} char_candidates: {cc}")
    user = "Danh sách từ:\n" + "\n".join(lines)
    schema = {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "han_viet": {"type": "string"},
                        "need_review": {"type": "boolean"},
                    },
                    "required": ["id", "han_viet", "need_review"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["items"],
        "additionalProperties": False,
    }
    return system, user, "han_viet_word_batch", schema


def build_han_viet_char_prompt(level: int, items: list[dict]) -> tuple[str, str, str, dict]:
    """items: [{id: char, candidates: [str,...]}] — id is the character itself."""
    system = (
        _SYSTEM_COMMON
        + " Nhiệm vụ: với mỗi chữ Hán, chọn MỘT âm Hán Việt đúng nhất trong danh sách "
        "'candidates'. Nếu danh sách rỗng, đề xuất âm Hán Việt hợp lý theo cách phát âm "
        "Hán Việt truyền thống và đặt need_review=true. Nếu chữ không có âm Hán Việt "
        "truyền thống chuẩn (ví dụ phụ tố hiện đại), để han_viet rỗng và need_review=true."
    )
    lines = [f"{i['id']}. {i['id']} candidates={i['candidates']}" for i in items]
    user = "Danh sách chữ:\n" + "\n".join(lines)
    schema = {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "han_viet": {"type": "string"},
                        "need_review": {"type": "boolean"},
                    },
                    "required": ["id", "han_viet", "need_review"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["items"],
        "additionalProperties": False,
    }
    return system, user, "han_viet_char_batch", schema


def build_example_prompt(level: int, items: list[dict]) -> tuple[str, str, str, dict]:
    """items: [{id, simplified, pinyin, meaning_vi}]"""
    system = (
        _SYSTEM_COMMON
        + f" Nhiệm vụ: với mỗi từ, đặt MỘT câu ví dụ tiếng Trung ngắn (dưới 12 chữ) "
        f"chỉ dùng từ vựng cơ bản trong phạm vi HSK{level} trở xuống, câu phải chứa "
        "đúng từ đích, văn phong tự nhiên như trong sách giáo trình HSK. Kèm bản dịch "
        "tiếng Việt sát nghĩa. Không dùng pinyin trong câu tiếng Trung."
    )
    lines = [f"{i['id']}. {i['simplified']} [{i['pinyin']}] nghĩa={i['meaning_vi']!r}" for i in items]
    user = "Danh sách từ cần đặt câu:\n" + "\n".join(lines)
    schema = {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "example_zh": {"type": "string"},
                        "example_vi": {"type": "string"},
                    },
                    "required": ["id", "example_zh", "example_vi"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["items"],
        "additionalProperties": False,
    }
    return system, user, "example_batch", schema
