"""SQLite schema + thin helpers for the master data-pipeline database.

Design notes (see docs/data-pipeline-plan.md section 4):
- One row per (simplified, pinyin_numeric) in `words` — a character with two
  readings (e.g. 了 le5 / liao3) is two rows, since meaning and usage differ.
- `candidates` holds every value a source or the LLM proposed for a field,
  so a reviewer can see alternatives without re-querying raw files.
- `status` on `words`/`chars` tracks how far a field has progressed:
  missing -> auto -> draft -> approved. Only `approved` rows are exported.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS sources (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    url TEXT NOT NULL,
    license TEXT NOT NULL,
    revision TEXT,
    sha256 TEXT,
    fetched_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS words (
    id INTEGER PRIMARY KEY,
    simplified TEXT NOT NULL,
    traditional TEXT,
    pinyin TEXT NOT NULL,
    pinyin_numeric TEXT NOT NULL,
    pos TEXT,
    hsk_level INTEGER NOT NULL,
    hsk2_level INTEGER,
    frequency INTEGER,
    meaning_en TEXT,
    meaning_vi TEXT,
    meaning_status TEXT NOT NULL DEFAULT 'missing',
    han_viet TEXT,
    han_viet_status TEXT NOT NULL DEFAULT 'missing',
    example_zh TEXT,
    example_pinyin TEXT,
    example_vi TEXT,
    example_status TEXT NOT NULL DEFAULT 'missing',
    notes TEXT,
    updated_at TEXT NOT NULL,
    UNIQUE (simplified, pinyin_numeric)
);
CREATE INDEX IF NOT EXISTS idx_words_level ON words (hsk_level);

CREATE TABLE IF NOT EXISTS chars (
    char TEXT PRIMARY KEY,
    traditional TEXT,
    hsk_level INTEGER NOT NULL,
    write_level INTEGER,
    han_viet TEXT,
    han_viet_status TEXT NOT NULL DEFAULT 'missing',
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS candidates (
    id INTEGER PRIMARY KEY,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('word', 'char')),
    entity_id TEXT NOT NULL,
    field TEXT NOT NULL,
    value TEXT NOT NULL,
    origin TEXT NOT NULL,
    rank INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_candidates_entity
    ON candidates (entity_type, entity_id, field);

CREATE TABLE IF NOT EXISTS grammar_points (
    id INTEGER PRIMARY KEY,
    level INTEGER NOT NULL,
    code TEXT NOT NULL,
    category TEXT,
    title_zh TEXT NOT NULL,
    items_json TEXT NOT NULL,
    pattern TEXT,
    explanation_vi TEXT,
    examples_json TEXT,
    status TEXT NOT NULL DEFAULT 'missing',
    UNIQUE (level, code)
);

CREATE TABLE IF NOT EXISTS lessons (
    id INTEGER PRIMARY KEY,
    level INTEGER NOT NULL,
    position INTEGER NOT NULL,
    title_zh TEXT,
    title_vi TEXT,
    topic TEXT,
    UNIQUE (level, position)
);
CREATE TABLE IF NOT EXISTS lesson_words (
    lesson_id INTEGER NOT NULL REFERENCES lessons(id),
    word_id INTEGER NOT NULL REFERENCES words(id),
    position INTEGER NOT NULL,
    PRIMARY KEY (lesson_id, word_id)
);
CREATE TABLE IF NOT EXISTS lesson_grammar (
    lesson_id INTEGER NOT NULL REFERENCES lessons(id),
    grammar_id INTEGER NOT NULL REFERENCES grammar_points(id),
    PRIMARY KEY (lesson_id, grammar_id)
);

CREATE TABLE IF NOT EXISTS batches (
    id INTEGER PRIMARY KEY,
    kind TEXT NOT NULL CHECK (kind IN ('meaning_vi', 'han_viet', 'example', 'grammar')),
    level INTEGER NOT NULL,
    size INTEGER NOT NULL,
    model TEXT,
    prompt_version TEXT,
    params_json TEXT,
    state TEXT NOT NULL DEFAULT 'created',
    created_at TEXT NOT NULL,
    finalized_at TEXT
);

CREATE TABLE IF NOT EXISTS batch_items (
    id INTEGER PRIMARY KEY,
    batch_id INTEGER NOT NULL REFERENCES batches(id),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('word', 'char', 'grammar')),
    entity_id TEXT NOT NULL,
    draft_json TEXT,
    final_json TEXT,
    warnings_json TEXT,
    llm_raw TEXT,
    error TEXT,
    decision TEXT NOT NULL DEFAULT 'pending',
    note TEXT,
    reviewed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_batch_items_batch ON batch_items (batch_id);

CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    field TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    actor TEXT NOT NULL,
    at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS pack_versions (
    level INTEGER PRIMARY KEY,
    version INTEGER NOT NULL,
    content_sha256 TEXT NOT NULL,
    file_sha256 TEXT,
    counts_json TEXT,
    exported_at TEXT NOT NULL
);
"""


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(db_path: Path) -> sqlite3.Connection:
    conn = connect(db_path)
    conn.executescript(SCHEMA)
    conn.commit()
    return conn
