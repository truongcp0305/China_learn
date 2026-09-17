"""Command-line entry point for the HSK data pipeline.

    python -m pipeline.cli fetch --levels 1,2,3
    python -m pipeline.cli import-syllabus --levels 1,2,3
    python -m pipeline.cli overview
"""
from __future__ import annotations

import argparse
import sys

from .config import load_config
from .db import connect, init_db
from .export import export_levels
from .fetch import fetch_all
from .importers.syllabus import build_level, persist


def _parse_levels(s: str) -> list[int]:
    return sorted({int(x) for x in s.split(",") if x.strip()})


def cmd_fetch(args: argparse.Namespace) -> None:
    cfg = load_config()
    conn = init_db(cfg.db_path)
    levels = _parse_levels(args.levels)
    print(f"Fetching sources for levels {levels}...")
    fetch_all(cfg, conn, levels)
    for row in conn.execute("SELECT name, sha256, fetched_at FROM sources ORDER BY name"):
        print(f"  {row['name']:45s} {row['sha256'][:12]}  {row['fetched_at']}")


def cmd_import_syllabus(args: argparse.Namespace) -> None:
    cfg = load_config()
    conn = init_db(cfg.db_path)
    for level in _parse_levels(args.levels):
        data = build_level(cfg.raw_dir, level)
        stats = persist(conn, cfg.raw_dir, data)
        print(f"HSK{level}: {stats}")
        if data.unresolved_words:
            print(f"  UNRESOLVED (need manual pinyin): {data.unresolved_words}")


def cmd_overview(args: argparse.Namespace) -> None:
    cfg = load_config()
    conn = connect(cfg.db_path)
    print("Words by level / meaning status:")
    for row in conn.execute(
        "SELECT hsk_level, meaning_status, COUNT(*) c FROM words GROUP BY hsk_level, meaning_status ORDER BY hsk_level, meaning_status"
    ):
        print(f"  HSK{row['hsk_level']}  {row['meaning_status']:8s} {row['c']}")
    print("Words by level / han_viet status:")
    for row in conn.execute(
        "SELECT hsk_level, han_viet_status, COUNT(*) c FROM words GROUP BY hsk_level, han_viet_status ORDER BY hsk_level, han_viet_status"
    ):
        print(f"  HSK{row['hsk_level']}  {row['han_viet_status']:8s} {row['c']}")
    print("Chars by level / han_viet status:")
    for row in conn.execute(
        "SELECT hsk_level, han_viet_status, COUNT(*) c FROM chars GROUP BY hsk_level, han_viet_status ORDER BY hsk_level, han_viet_status"
    ):
        print(f"  HSK{row['hsk_level']}  {row['han_viet_status']:8s} {row['c']}")
    ambiguous = conn.execute(
        "SELECT COUNT(DISTINCT entity_id) c FROM candidates WHERE entity_type='word' AND field='pinyin' "
        "AND entity_id IN (SELECT entity_id FROM candidates WHERE entity_type='word' AND field='pinyin' GROUP BY entity_id HAVING COUNT(*) > 1)"
    ).fetchone()["c"]
    print(f"Words with ambiguous (multi-reading) pinyin needing a manual pick: {ambiguous}")


def cmd_export(args: argparse.Namespace) -> None:
    cfg = load_config()
    conn = connect(cfg.db_path)
    reports = export_levels(conn, cfg, _parse_levels(args.levels))
    for r in reports:
        print(f"HSK{r['level']} v{r['version']} ({'đổi' if r['changed'] else 'không đổi'}): "
              f"{r['words_included']} từ (bỏ {r['words_skipped']}), {r['chars_included']} chữ "
              f"({r['chars_with_han_viet']} có Hán Việt), {r['grammar_included']} ngữ pháp, {r['lessons_included']} bài")
    print(f"Đã ghi {cfg.dist_dir / 'manifest.json'}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="pipeline.cli")
    sub = parser.add_subparsers(dest="command", required=True)

    p_fetch = sub.add_parser("fetch", help="Download pinned sources into data/raw/")
    p_fetch.add_argument("--levels", default="1,2,3", help="Comma-separated HSK levels")
    p_fetch.set_defaults(func=cmd_fetch)

    p_import = sub.add_parser("import-syllabus", help="Build words/chars for given levels from raw sources")
    p_import.add_argument("--levels", default="1,2,3")
    p_import.set_defaults(func=cmd_import_syllabus)

    p_overview = sub.add_parser("overview", help="Print coverage counts from the master DB")
    p_overview.set_defaults(func=cmd_overview)

    p_export = sub.add_parser("export", help="Write dist/packs/hsk{n}.json + dist/manifest.json from approved data")
    p_export.add_argument("--levels", default="1,2,3")
    p_export.set_defaults(func=cmd_export)

    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
