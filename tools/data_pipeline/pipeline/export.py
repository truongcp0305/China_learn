"""Exports approved data to dist/packs/hsk{level}.json + dist/manifest.json
for the app to download (plan section 5, B9).

Only `approved` (or `edited`, which is an approved value the reviewer typed
over) content ships — anything still `missing`/`auto`/`draft` is left out of
the pack entirely (required fields) or just omitted (optional fields), never
exported half-reviewed. Re-running is idempotent: the pack's `version` only
increases when its content actually changes.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from .config import Config

_APPROVED = ("approved", "edited")

CREDITS = [
    {
        "name": "CVDICT",
        "author": "Phong Phan",
        "url": "https://github.com/ph0ngp/CVDICT",
        "license": "CC BY-SA 4.0",
    },
    {
        "name": "CC-CEDICT",
        "author": "MDBG",
        "url": "https://www.mdbg.net/chinese/dictionary?page=cc-cedict",
        "license": "CC BY-SA 4.0",
    },
    {
        "name": "complete-hsk-vocabulary",
        "author": "drkameleon",
        "url": "https://github.com/drkameleon/complete-hsk-vocabulary",
        "license": "MIT",
    },
    {
        "name": "Unicode Unihan Database",
        "author": "Unicode Consortium",
        "url": "https://www.unicode.org/reports/tr38/",
        "license": "Unicode License",
    },
    {
        "name": "HSK 3.0 syllabus word/grammar lists",
        "author": "krmanik (from the official MOE/CTI HSK 3.0 syllabus)",
        "url": "https://github.com/krmanik/HSK-3.0",
        "license": "Derived from the official syllabus",
    },
    {
        "name": "sino-vietnamese-readings",
        "author": "evotone",
        "url": "https://github.com/evotone/sinov",
        "license": "UNSPECIFIED — personal use only, not yet cleared for release",
    },
]

SCHEMA_VERSION = 1


def _content_hash(payload: dict) -> str:
    stripped = {k: v for k, v in payload.items() if k not in ("version", "generated_at")}
    blob = json.dumps(stripped, sort_keys=True, ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()


def build_pack(conn: sqlite3.Connection, level: int) -> tuple[dict, dict]:
    """Returns (pack_dict, report) where report lists what was left out and why."""
    word_rows = conn.execute("SELECT * FROM words WHERE hsk_level=? ORDER BY id", (level,)).fetchall()
    words = []
    skipped_words = []
    for r in word_rows:
        if r["meaning_status"] not in _APPROVED or not r["simplified"] or not r["pinyin"] or not r["meaning_vi"]:
            skipped_words.append({"simplified": r["simplified"], "reason": f"meaning_status={r['meaning_status']}"})
            continue
        entry = {
            "simplified": r["simplified"],
            "traditional": r["traditional"],
            "pinyin": r["pinyin"],
            "pos": r["pos"] or None,
            "meaning_vi": r["meaning_vi"],
            "hsk2_level": r["hsk2_level"],
        }
        if r["han_viet_status"] in _APPROVED and r["han_viet"]:
            entry["han_viet"] = r["han_viet"]
        if r["example_status"] in _APPROVED and r["example_zh"]:
            entry["example_zh"] = r["example_zh"]
            entry["example_pinyin"] = r["example_pinyin"]
            entry["example_vi"] = r["example_vi"]
        words.append(entry)

    char_rows = conn.execute("SELECT * FROM chars WHERE hsk_level=? ORDER BY char", (level,)).fetchall()
    chars = []
    for r in char_rows:
        entry = {"char": r["char"], "traditional": r["traditional"], "write_level": r["write_level"]}
        if r["han_viet_status"] in _APPROVED and r["han_viet"]:
            entry["han_viet"] = r["han_viet"]
        chars.append(entry)

    grammar_rows = conn.execute("SELECT * FROM grammar_points WHERE level=? AND status IN (?,?) ORDER BY code", (level, *_APPROVED)).fetchall()
    grammar = [
        {
            "code": r["code"],
            "category": r["category"],
            "title_zh": r["title_zh"],
            "items": json.loads(r["items_json"]) if r["items_json"] else [],
            "pattern": r["pattern"],
            "explanation_vi": r["explanation_vi"],
            "examples": json.loads(r["examples_json"]) if r["examples_json"] else [],
        }
        for r in grammar_rows
    ]

    lesson_rows = conn.execute("SELECT * FROM lessons WHERE level=? ORDER BY position", (level,)).fetchall()
    lessons = []
    for lr in lesson_rows:
        word_ids = [w["word_id"] for w in conn.execute(
            "SELECT word_id FROM lesson_words WHERE lesson_id=? ORDER BY position", (lr["id"],)
        )]
        simplified_by_id = {r["id"]: r["simplified"] for r in word_rows}
        lessons.append({
            "position": lr["position"], "title_zh": lr["title_zh"], "title_vi": lr["title_vi"], "topic": lr["topic"],
            "words": [simplified_by_id[wid] for wid in word_ids if wid in simplified_by_id],
        })

    pack = {
        "schema_version": SCHEMA_VERSION,
        "level": level,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "credits": CREDITS,
        "words": words,
        "chars": chars,
        "grammar": grammar,
        "lessons": lessons,
    }
    report = {
        "level": level,
        "words_included": len(words),
        "words_skipped": len(skipped_words),
        "skipped_examples": skipped_words[:10],
        "chars_included": len(chars),
        "chars_with_han_viet": sum(1 for c in chars if "han_viet" in c),
        "grammar_included": len(grammar),
        "lessons_included": len(lessons),
    }
    return pack, report


def write_pack(conn: sqlite3.Connection, cfg: Config, level: int) -> dict:
    pack, report = build_pack(conn, level)
    content_hash = _content_hash(pack)

    existing = conn.execute("SELECT * FROM pack_versions WHERE level=?", (level,)).fetchone()
    if existing and existing["content_sha256"] == content_hash:
        version = existing["version"]
    else:
        version = (existing["version"] + 1) if existing else 1

    pack["version"] = version
    packs_dir = cfg.dist_dir / "packs"
    packs_dir.mkdir(parents=True, exist_ok=True)
    out_path = packs_dir / f"hsk{level}.json"
    blob = json.dumps(pack, ensure_ascii=False, indent=2)
    out_path.write_text(blob, encoding="utf-8")
    file_hash = hashlib.sha256(blob.encode("utf-8")).hexdigest()

    conn.execute(
        """INSERT INTO pack_versions (level, version, content_sha256, file_sha256, counts_json, exported_at)
           VALUES (?,?,?,?,?,?)
           ON CONFLICT(level) DO UPDATE SET version=excluded.version, content_sha256=excluded.content_sha256,
             file_sha256=excluded.file_sha256, counts_json=excluded.counts_json, exported_at=excluded.exported_at""",
        (level, version, content_hash, file_hash, json.dumps(report, ensure_ascii=False), datetime.now(timezone.utc).isoformat()),
    )
    conn.commit()

    report["version"] = version
    report["changed"] = not existing or existing["content_sha256"] != content_hash
    report["file"] = str(out_path)
    report["file_sha256"] = file_hash
    return report


def write_manifest(conn: sqlite3.Connection, cfg: Config) -> Path:
    rows = conn.execute("SELECT * FROM pack_versions ORDER BY level").fetchall()
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "packs": [
            {
                "level": r["level"],
                "version": r["version"],
                "file": f"packs/hsk{r['level']}.json",
                "sha256": r["file_sha256"],
                "counts": json.loads(r["counts_json"]) if r["counts_json"] else {},
            }
            for r in rows
        ],
    }
    out_path = cfg.dist_dir / "manifest.json"
    out_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return out_path


def export_levels(conn: sqlite3.Connection, cfg: Config, levels: list[int]) -> list[dict]:
    reports = [write_pack(conn, cfg, level) for level in levels]
    write_manifest(conn, cfg)
    return reports
