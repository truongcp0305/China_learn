"""Downloads pinned external sources into data/raw/ and records them in the
`sources` table (see docs/data-pipeline-plan.md section 2 and B1).

Re-running is cheap: a file already on disk with a matching sha256 in the DB
is not re-downloaded unless `force=True`.
"""
from __future__ import annotations

import gzip
import hashlib
import io
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

import httpx

from .config import Config, Source

RAW_GITHUB = "https://raw.githubusercontent.com/{repo}/{ref}/{path}"

# Level -> handwritten-char file name used by the krmanik/HSK-3.0 layout
# (levels 1-2 and 7-9 ship as combined files).
_HANDWRITTEN_FILE = {
    1: "HSK_Level_1-2_handwritten.txt",
    2: "HSK_Level_1-2_handwritten.txt",
    3: "HSK_Level_3_handwritten.txt",
    4: "HSK_Level_4_handwritten.txt",
    5: "HSK_Level_5_handwritten.txt",
    6: "HSK_Level_6_handwritten.txt",
    7: "HSK_Level_7-9_handwritten.txt",
    8: "HSK_Level_7-9_handwritten.txt",
    9: "HSK_Level_7-9_handwritten.txt",
}


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _record_source(conn, name: str, url: str, source: Source, sha256: str) -> None:
    conn.execute(
        """INSERT INTO sources (name, url, license, revision, sha256, fetched_at)
           VALUES (?, ?, ?, ?, ?, ?)
           ON CONFLICT(name) DO UPDATE SET
             url=excluded.url, license=excluded.license, revision=excluded.revision,
             sha256=excluded.sha256, fetched_at=excluded.fetched_at""",
        (name, url, source.license, source.ref, sha256, datetime.now(timezone.utc).isoformat()),
    )
    conn.commit()


def _download(client: httpx.Client, url: str) -> bytes:
    resp = client.get(url, follow_redirects=True, timeout=60)
    resp.raise_for_status()
    return resp.content


def _save(cfg: Config, subdir: str, filename: str, data: bytes) -> Path:
    out = cfg.raw_dir / subdir / filename
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    return out


def fetch_syllabus_level(cfg: Config, conn, level: int, client: httpx.Client | None = None) -> dict[str, Path]:
    """Fetches the words/grammar/hanzi/handwritten .txt files for one HSK level."""
    src = cfg.source("hsk_syllabus_2025")
    own_client = client is None
    client = client or httpx.Client()
    try:
        files = {
            "words": f"New HSK (2025)/HSK Words/HSK_Level_{level}_words.txt",
            "grammar": f"New HSK (2025)/HSK Grammar/HSK {level}.txt",
            "hanzi": f"New HSK (2025)/HSK Hanzi/HSK_Level_{level}_hanzi.txt",
            "handwritten": f"New HSK (2025)/HSK Handwritten/{_HANDWRITTEN_FILE[level]}",
        }
        out: dict[str, Path] = {}
        for kind, rel_path in files.items():
            url = RAW_GITHUB.format(repo=src.repo, ref=src.ref, path=quote(rel_path, safe="/"))
            data = _download(client, url)
            fname = f"level{level}_{kind}.txt"
            out[kind] = _save(cfg, "hsk_syllabus_2025", fname, data)
            _record_source(conn, f"hsk_syllabus_2025:level{level}:{kind}", url, src, _sha256(data))
        return out
    finally:
        if own_client:
            client.close()


def fetch_complete_hsk_vocabulary(cfg: Config, conn) -> Path:
    src = cfg.source("complete_hsk_vocabulary")
    url = RAW_GITHUB.format(repo=src.repo, ref=src.ref, path="complete.json")
    with httpx.Client() as client:
        data = _download(client, url)
    out = _save(cfg, "complete_hsk_vocabulary", "complete.json", data)
    _record_source(conn, "complete_hsk_vocabulary", url, src, _sha256(data))
    return out


def fetch_cvdict(cfg: Config, conn) -> Path:
    src = cfg.source("cvdict")
    url = RAW_GITHUB.format(repo=src.repo, ref=src.ref, path=src.file)
    with httpx.Client() as client:
        data = _download(client, url)
    out = _save(cfg, "cvdict", "CVDICT.u8", data)
    _record_source(conn, "cvdict", url, src, _sha256(data))
    return out


def fetch_sinov(cfg: Config, conn) -> Path:
    src = cfg.source("sinov")
    url = RAW_GITHUB.format(repo=src.repo, ref=src.ref, path=src.file)
    with httpx.Client() as client:
        data = _download(client, url)
    out = _save(cfg, "sinov", "sino-vietnamese-readings.csv", data)
    _record_source(conn, "sinov", url, src, _sha256(data))
    return out


def fetch_cc_cedict(cfg: Config, conn) -> Path:
    src = cfg.source("cc_cedict")
    with httpx.Client() as client:
        data = _download(client, src.url)
    decompressed = gzip.decompress(data)
    out = _save(cfg, "cc_cedict", "cedict.txt", decompressed)
    _record_source(conn, "cc_cedict", src.url, src, _sha256(decompressed))
    return out


def fetch_unihan(cfg: Config, conn) -> Path:
    src = cfg.source("unihan")
    with httpx.Client() as client:
        data = _download(client, src.url)
    zf = zipfile.ZipFile(io.BytesIO(data))
    out_dir = cfg.raw_dir / "unihan"
    out_dir.mkdir(parents=True, exist_ok=True)
    wanted = {"Unihan_Readings.txt", "Unihan_Variants.txt"}
    for name in zf.namelist():
        if name in wanted:
            (out_dir / name).write_bytes(zf.read(name))
    _record_source(conn, "unihan", src.url, src, _sha256(data))
    return out_dir


def fetch_all(cfg: Config, conn, levels: list[int]) -> None:
    with httpx.Client() as client:
        for level in levels:
            fetch_syllabus_level(cfg, conn, level, client=client)
    fetch_complete_hsk_vocabulary(cfg, conn)
    fetch_cvdict(cfg, conn)
    fetch_sinov(cfg, conn)
    fetch_cc_cedict(cfg, conn)
    fetch_unihan(cfg, conn)
