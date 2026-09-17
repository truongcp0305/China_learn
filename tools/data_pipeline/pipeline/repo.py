"""Read/write helpers shared by the FastAPI server (and, later, the LLM batch
runner) — kept separate from db.py's schema so the API layer doesn't hold
raw SQL. Every mutating function takes `actor` and writes `audit_log`.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def overview(conn: sqlite3.Connection) -> dict:
    def counts(table: str, status_col: str) -> list[dict]:
        rows = conn.execute(
            f"SELECT hsk_level, {status_col} AS status, COUNT(*) c FROM {table} GROUP BY hsk_level, {status_col} ORDER BY hsk_level"
        ).fetchall()
        return [dict(r) for r in rows]

    ambiguous = conn.execute(
        """SELECT hsk_level, COUNT(*) c FROM words WHERE id IN (
             SELECT CAST(entity_id AS INTEGER) FROM candidates
             WHERE entity_type='word' AND field='pinyin'
             GROUP BY entity_id HAVING COUNT(*) > 1
           ) GROUP BY hsk_level"""
    ).fetchall()

    return {
        "words_meaning": counts("words", "meaning_status"),
        "words_han_viet": counts("words", "han_viet_status"),
        "words_example": counts("words", "example_status"),
        "chars_han_viet": counts("chars", "han_viet_status"),
        "words_ambiguous_pinyin": [dict(r) for r in ambiguous],
    }


def list_words(conn: sqlite3.Connection, level: int, status: str | None, field: str, limit: int, offset: int) -> dict:
    status_col = {"meaning_vi": "meaning_status", "han_viet": "han_viet_status", "example": "example_status"}[field]
    where = "WHERE hsk_level=?"
    params: list = [level]
    if status:
        where += f" AND {status_col}=?"
        params.append(status)
    total = conn.execute(f"SELECT COUNT(*) c FROM words {where}", params).fetchone()["c"]
    rows = conn.execute(
        f"SELECT * FROM words {where} ORDER BY id LIMIT ? OFFSET ?", params + [limit, offset]
    ).fetchall()
    items = []
    for row in rows:
        d = dict(row)
        d["candidates"] = {
            f: [dict(c) for c in conn.execute(
                "SELECT value, origin, rank FROM candidates WHERE entity_type='word' AND entity_id=? AND field=? ORDER BY rank",
                (str(row["id"]), f),
            )]
            for f in ("pinyin", "meaning_vi")
        }
        d["llm_warnings"] = _latest_warnings(conn, "word", str(row["id"]))
        items.append(d)
    return {"total": total, "items": items}


def _latest_warnings(conn: sqlite3.Connection, entity_type: str, entity_id: str) -> list[str]:
    row = conn.execute(
        "SELECT warnings_json FROM batch_items WHERE entity_type=? AND entity_id=? AND warnings_json IS NOT NULL ORDER BY id DESC LIMIT 1",
        (entity_type, entity_id),
    ).fetchone()
    return json.loads(row["warnings_json"]) if row else []


def list_chars(conn: sqlite3.Connection, level: int, status: str | None, limit: int, offset: int) -> dict:
    where = "WHERE hsk_level=?"
    params: list = [level]
    if status:
        where += " AND han_viet_status=?"
        params.append(status)
    total = conn.execute(f"SELECT COUNT(*) c FROM chars {where}", params).fetchone()["c"]
    rows = conn.execute(f"SELECT * FROM chars {where} ORDER BY char LIMIT ? OFFSET ?", params + [limit, offset]).fetchall()
    items = []
    for row in rows:
        d = dict(row)
        d["candidates"] = [
            dict(c) for c in conn.execute(
                "SELECT value, origin, rank FROM candidates WHERE entity_type='char' AND entity_id=? AND field='han_viet' ORDER BY rank",
                (row["char"],),
            )
        ]
        d["llm_warnings"] = _latest_warnings(conn, "char", row["char"])
        items.append(d)
    return {"total": total, "items": items}


_WORD_EDITABLE = {"pinyin", "meaning_vi", "han_viet", "example_zh", "example_pinyin", "example_vi", "notes"}
_WORD_STATUS_FIELDS = {"meaning_vi": "meaning_status", "han_viet": "han_viet_status", "example": "example_status"}


def update_word(conn: sqlite3.Connection, word_id: int, patch: dict, actor: str) -> dict:
    row = conn.execute("SELECT * FROM words WHERE id=?", (word_id,)).fetchone()
    if row is None:
        raise KeyError(f"word {word_id} not found")

    sets, params = [], []
    for key, value in patch.items():
        if key not in _WORD_EDITABLE:
            continue
        old = row[key]
        if old == value:
            continue
        sets.append(f"{key}=?")
        params.append(value)
        conn.execute(
            "INSERT INTO audit_log (entity_type, entity_id, field, old_value, new_value, actor, at) VALUES ('word',?,?,?,?,?,?)",
            (str(word_id), key, old, value, actor, _now()),
        )
    # A manual edit to a tracked field promotes its status to "edited" unless
    # the caller is also setting status explicitly (e.g. approving).
    for content_field, status_col in _WORD_STATUS_FIELDS.items():
        touched = content_field in patch or (content_field == "meaning_vi" and "meaning_vi" in patch)
        status_key = f"{status_col}"
        if status_key in patch:
            sets.append(f"{status_col}=?")
            params.append(patch[status_key])
        elif touched and row[status_col] == "approved":
            sets.append(f"{status_col}=?")
            params.append("edited")
    if not sets:
        return dict(row)
    sets.append("updated_at=?")
    params.append(_now())
    params.append(word_id)
    conn.execute(f"UPDATE words SET {', '.join(sets)} WHERE id=?", params)
    conn.commit()
    return dict(conn.execute("SELECT * FROM words WHERE id=?", (word_id,)).fetchone())


def approve_word_field(conn: sqlite3.Connection, word_id: int, field: str, value: str | None, actor: str) -> dict:
    status_col = _WORD_STATUS_FIELDS[field]
    patch = {status_col: "approved"}
    if value is not None:
        patch[field] = value
    return update_word(conn, word_id, patch, actor)


def update_char(conn: sqlite3.Connection, char: str, patch: dict, actor: str) -> dict:
    row = conn.execute("SELECT * FROM chars WHERE char=?", (char,)).fetchone()
    if row is None:
        raise KeyError(f"char {char} not found")
    sets, params = [], []
    if "han_viet" in patch and patch["han_viet"] != row["han_viet"]:
        sets.append("han_viet=?")
        params.append(patch["han_viet"])
        conn.execute(
            "INSERT INTO audit_log (entity_type, entity_id, field, old_value, new_value, actor, at) VALUES ('char',?,?,?,?,?,?)",
            (char, "han_viet", row["han_viet"], patch["han_viet"], actor, _now()),
        )
    if "han_viet_status" in patch:
        sets.append("han_viet_status=?")
        params.append(patch["han_viet_status"])
    elif "han_viet" in patch and row["han_viet_status"] == "approved":
        sets.append("han_viet_status=?")
        params.append("edited")
    if not sets:
        return dict(row)
    sets.append("updated_at=?")
    params.append(_now())
    params.append(char)
    conn.execute(f"UPDATE chars SET {', '.join(sets)} WHERE char=?", params)
    conn.commit()
    return dict(conn.execute("SELECT * FROM chars WHERE char=?", (char,)).fetchone())
