"""Orchestrates one LLM batch run (plan section 5, B6+B7): pick candidate
rows, call LM Studio in chunks, write the result back into `words`/`chars`
as a fresh draft (never touching rows already `approved`), and keep a
`batches`/`batch_items` audit trail with warnings from validate.py.

The reviewer still approves everything through the same words/chars API the
rule-based drafts use (server.py) — an LLM batch only ever produces another
`draft`, identical in shape to a rule-based one, just with a better guess
and a `warnings` note attached.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone

from pypinyin import Style, pinyin as pypinyin_convert

from .config import Config
from .llm import LmStudioClient
from .prompts import (
    PROMPT_VERSION,
    build_example_prompt,
    build_han_viet_char_prompt,
    build_han_viet_word_prompt,
    build_meaning_prompt,
)
from .validate import validate_example, validate_han_viet_word, validate_meaning_vi

CHUNK_SIZE = 12


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def select_words_for_meaning(conn: sqlite3.Connection, level: int, limit: int) -> list[dict]:
    rows = conn.execute(
        """SELECT w.id, w.simplified, w.pinyin, w.meaning_en, w.meaning_status
           FROM words w WHERE w.hsk_level=? AND w.meaning_status NOT IN ('approved','edited')
           ORDER BY w.id""",
        (level,),
    ).fetchall()
    out = []
    for r in rows:
        cands = [c["value"] for c in conn.execute(
            "SELECT value FROM candidates WHERE entity_type='word' AND entity_id=? AND field='meaning_vi' ORDER BY rank LIMIT 6",
            (str(r["id"]),),
        )]
        if r["meaning_status"] == "missing" or len(set(cands)) > 1:
            out.append({"id": r["id"], "simplified": r["simplified"], "pinyin": r["pinyin"],
                        "candidates": cands or ([r["meaning_en"]] if r["meaning_en"] else [])})
        if len(out) >= limit:
            break
    return out


def select_words_for_han_viet(conn: sqlite3.Connection, level: int, limit: int) -> list[dict]:
    rows = conn.execute(
        """SELECT id, simplified, pinyin, meaning_vi FROM words
           WHERE hsk_level=? AND han_viet_status NOT IN ('approved','edited') AND LENGTH(simplified) > 1
           ORDER BY id LIMIT ?""",
        (level, limit),
    ).fetchall()
    out = []
    for r in rows:
        char_candidates = {}
        for ch in r["simplified"]:
            crow = conn.execute("SELECT han_viet FROM chars WHERE char=?", (ch,)).fetchone()
            cands = [c["value"] for c in conn.execute(
                "SELECT value FROM candidates WHERE entity_type='char' AND entity_id=? AND field='han_viet' ORDER BY rank",
                (ch,),
            )]
            char_candidates[ch] = cands or ([crow["han_viet"]] if crow and crow["han_viet"] else [])
        out.append({"id": r["id"], "simplified": r["simplified"], "pinyin": r["pinyin"],
                     "meaning_vi": r["meaning_vi"] or "", "char_candidates": char_candidates})
    return out


def select_chars_for_han_viet(conn: sqlite3.Connection, level: int, limit: int) -> list[dict]:
    rows = conn.execute(
        "SELECT char FROM chars WHERE hsk_level=? AND han_viet_status NOT IN ('approved','edited') ORDER BY char LIMIT ?",
        (level, limit),
    ).fetchall()
    out = []
    for r in rows:
        cands = [c["value"] for c in conn.execute(
            "SELECT value FROM candidates WHERE entity_type='char' AND entity_id=? AND field='han_viet' ORDER BY rank",
            (r["char"],),
        )]
        out.append({"id": r["char"], "candidates": cands})
    return out


def select_words_for_example(conn: sqlite3.Connection, level: int, limit: int) -> list[dict]:
    rows = conn.execute(
        """SELECT id, simplified, pinyin, meaning_vi FROM words
           WHERE hsk_level=? AND example_status='missing' AND meaning_vi IS NOT NULL AND meaning_vi != ''
           ORDER BY id LIMIT ?""",
        (level, limit),
    ).fetchall()
    return [{"id": r["id"], "simplified": r["simplified"], "pinyin": r["pinyin"], "meaning_vi": r["meaning_vi"]} for r in rows]


def _allowed_vocabulary(conn: sqlite3.Connection, level: int) -> set[str]:
    words = {r["simplified"] for r in conn.execute("SELECT simplified FROM words WHERE hsk_level<=?", (level,))}
    chars = {r["char"] for r in conn.execute("SELECT char FROM chars WHERE hsk_level<=?", (level,))}
    return words | chars


def _chunks(items: list, size: int):
    for i in range(0, len(items), size):
        yield items[i : i + size]


def run_batch(conn: sqlite3.Connection, cfg: Config, kind: str, entity_type: str, level: int, size: int, model: str) -> dict:
    """kind: 'meaning_vi' | 'han_viet' | 'example'. entity_type: 'word' | 'char'
    (entity_type only matters for kind='han_viet'; meaning_vi/example are word-only)."""
    if kind == "meaning_vi":
        items = select_words_for_meaning(conn, level, size)
    elif kind == "han_viet" and entity_type == "char":
        items = select_chars_for_han_viet(conn, level, size)
    elif kind == "han_viet":
        items = select_words_for_han_viet(conn, level, size)
    elif kind == "example":
        items = select_words_for_example(conn, level, size)
    else:
        raise ValueError(f"unknown kind {kind!r}")

    batch_id = conn.execute(
        "INSERT INTO batches (kind, level, size, model, prompt_version, params_json, state, created_at) VALUES (?,?,?,?,?,?,?,?)",
        (kind, level, len(items), model, PROMPT_VERSION, json.dumps({"entity_type": entity_type}), "created", _now()),
    ).lastrowid
    conn.commit()

    if not items:
        conn.execute("UPDATE batches SET state='ready', finalized_at=? WHERE id=?", (_now(), batch_id))
        conn.commit()
        return {"batch_id": batch_id, "processed": 0, "errors": 0, "warnings": 0, "message": "không còn mục nào cần xử lý"}

    conn.execute("UPDATE batches SET state='drafting' WHERE id=?", (batch_id,))
    conn.commit()

    client = LmStudioClient(cfg)
    allowed_vocab = _allowed_vocabulary(conn, level) if kind == "example" else set()
    processed = errors = warned = 0
    try:
        for chunk in _chunks(items, CHUNK_SIZE):
            try:
                if kind == "meaning_vi":
                    system, user, name, schema = build_meaning_prompt(level, chunk)
                elif kind == "han_viet" and entity_type == "char":
                    system, user, name, schema = build_han_viet_char_prompt(level, chunk)
                elif kind == "han_viet":
                    system, user, name, schema = build_han_viet_word_prompt(level, chunk)
                else:
                    system, user, name, schema = build_example_prompt(level, chunk)
                parsed, raw = client.chat_json(model, system, user, name, schema)
            except Exception as e:  # noqa: BLE001 - record and move to next chunk
                for it in chunk:
                    conn.execute(
                        "INSERT INTO batch_items (batch_id, entity_type, entity_id, error) VALUES (?,?,?,?)",
                        (batch_id, entity_type, str(it["id"]), str(e)),
                    )
                    errors += 1
                conn.commit()
                continue

            by_id = {str(r["id"]): r for r in parsed.get("items", [])}
            for it in chunk:
                key = str(it["id"])
                result = by_id.get(key)
                if result is None:
                    conn.execute(
                        "INSERT INTO batch_items (batch_id, entity_type, entity_id, error, llm_raw) VALUES (?,?,?,?,?)",
                        (batch_id, entity_type, key, "model không trả về mục này", raw),
                    )
                    errors += 1
                    continue

                warnings: list[str] = []
                if kind == "meaning_vi":
                    value = result["meaning_vi"].strip()
                    warnings = validate_meaning_vi(value)
                    conn.execute(
                        "UPDATE words SET meaning_vi=?, meaning_status='draft', updated_at=? WHERE id=? AND meaning_status NOT IN ('approved','edited')",
                        (value, _now(), it["id"]),
                    )
                    conn.execute(
                        "INSERT INTO candidates (entity_type, entity_id, field, value, origin, rank) VALUES ('word', ?, 'meaning_vi', ?, 'llm', -1)",
                        (key, value),
                    )
                elif kind == "han_viet" and entity_type == "char":
                    value = result["han_viet"].strip()
                    if result.get("need_review"):
                        warnings.append("LLM tự đề xuất (không nằm trong danh sách ứng viên gốc)")
                    conn.execute(
                        "UPDATE chars SET han_viet=?, han_viet_status='draft', updated_at=? WHERE char=? AND han_viet_status NOT IN ('approved','edited')",
                        (value, _now(), it["id"]),
                    )
                elif kind == "han_viet":
                    value = result["han_viet"].strip()
                    warnings = validate_han_viet_word(it["simplified"], value)
                    if result.get("need_review"):
                        warnings.append("có chữ LLM tự đề xuất âm (không nằm trong ứng viên gốc)")
                    conn.execute(
                        "UPDATE words SET han_viet=?, han_viet_status='draft', updated_at=? WHERE id=? AND han_viet_status NOT IN ('approved','edited')",
                        (value, _now(), it["id"]),
                    )
                else:  # example
                    zh = result["example_zh"].strip()
                    vi = result["example_vi"].strip()
                    # pypinyin, not the LLM, produces the pinyin — see plan B6.
                    pinyin_line = " ".join(s[0] for s in pypinyin_convert(zh, style=Style.TONE))
                    warnings = validate_example(zh, it["simplified"], allowed_vocab)
                    conn.execute(
                        """UPDATE words SET example_zh=?, example_pinyin=?, example_vi=?, example_status='draft', updated_at=?
                           WHERE id=? AND example_status NOT IN ('approved','edited')""",
                        (zh, pinyin_line, vi, _now(), it["id"]),
                    )

                conn.execute(
                    """INSERT INTO batch_items (batch_id, entity_type, entity_id, draft_json, warnings_json, llm_raw, decision)
                       VALUES (?,?,?,?,?,?,?)""",
                    (batch_id, entity_type, key, json.dumps(result, ensure_ascii=False),
                     json.dumps(warnings, ensure_ascii=False) if warnings else None, raw, "pending"),
                )
                processed += 1
                if warnings:
                    warned += 1
            conn.commit()
    finally:
        client.close()

    conn.execute("UPDATE batches SET state='ready', finalized_at=? WHERE id=?", (_now(), batch_id))
    conn.commit()
    return {"batch_id": batch_id, "processed": processed, "errors": errors, "warnings": warned}
