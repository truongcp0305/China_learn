"""Builds the Han-Viet (Sino-Vietnamese) reading candidate list per character
(plan section 2, B4): union of evotone/sinov readings and Unicode Unihan's
`kVietnamese` field, both looked up through `kTraditionalVariant` so a
simplified character also picks up readings recorded only for its
traditional form.
"""
from __future__ import annotations

import csv
import re
from pathlib import Path

_PAREN = re.compile(r"[（(]([^）)]*)[）)]")


def _split_reading(raw: str) -> list[str]:
    """A handful of sinov rows glue two readings into one cell instead of
    two rows, e.g. 西 -> "Tê (Tây)". Splits "X (Y)" into ["x", "y"] instead
    of keeping the literal "x (y)" as a single bogus candidate."""
    inner = [m.strip() for m in _PAREN.findall(raw) if m.strip()]
    outer = _PAREN.sub("", raw).strip()
    parts = ([outer] if outer else []) + inner
    return parts or ([raw.strip()] if raw.strip() else [])


def load_sinov(path: Path) -> dict[str, list[str]]:
    """CSV columns: 汉字,漢越語,IPA — one row per (character, reading)."""
    out: dict[str, list[str]] = {}
    with open(path, encoding="utf-8-sig", newline="") as f:
        for row in csv.reader(f):
            if len(row) < 2 or not row[0]:
                continue
            char, raw_reading = row[0], row[1].strip().lower()
            if not raw_reading:
                continue
            bucket = out.setdefault(char, [])
            for reading in _split_reading(raw_reading):
                if reading not in bucket:
                    bucket.append(reading)
    return out


def _parse_unihan_field(path: Path, field: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3 or parts[1] != field:
            continue
        cp = int(parts[0][2:], 16)
        out[chr(cp)] = parts[2]
    return out


def load_unihan_vietnamese(readings_path: Path) -> dict[str, list[str]]:
    raw = _parse_unihan_field(readings_path, "kVietnamese")
    return {c: [r.strip().lower() for r in v.split()] for c, v in raw.items()}


def load_unihan_traditional_variants(variants_path: Path) -> dict[str, list[str]]:
    raw = _parse_unihan_field(variants_path, "kTraditionalVariant")
    out: dict[str, list[str]] = {}
    for c, v in raw.items():
        # values look like "U+508C U+5AAF<kMatthews,kFenn" — strip source tags
        codes = [tok.split("<")[0] for tok in v.split()]
        out[c] = [chr(int(code[2:], 16)) for code in codes if code.startswith("U+")]
    return out


class HanVietIndex:
    """Merges sinov + Unihan and resolves through traditional variants."""

    def __init__(self, raw_dir: Path):
        self.sinov = load_sinov(raw_dir / "sinov" / "sino-vietnamese-readings.csv")
        self.unihan = load_unihan_vietnamese(raw_dir / "unihan" / "Unihan_Readings.txt")
        self.trad = load_unihan_traditional_variants(raw_dir / "unihan" / "Unihan_Variants.txt")

    def candidates(self, char: str) -> list[str]:
        seen: list[str] = []

        def add_all(source: dict[str, list[str]], c: str) -> None:
            for r in source.get(c, []):
                if r not in seen:
                    seen.append(r)

        add_all(self.sinov, char)
        add_all(self.unihan, char)
        for trad_char in self.trad.get(char, []):
            add_all(self.sinov, trad_char)
            add_all(self.unihan, trad_char)
        return seen

    def sinov_confirms(self, char: str) -> bool:
        """True if evotone/sinov (curated Sino-Vietnamese readings) has an
        entry for this char or its traditional variant, as opposed to a
        reading known only from Unihan's `kVietnamese` — which sometimes
        holds a Nom (non-Sino-Vietnamese) reading instead, e.g. 们 -> "món".
        Used to gate the 'auto' status: a single Unihan-only candidate is
        not trustworthy enough to auto-approve without review."""
        if char in self.sinov:
            return True
        return any(t in self.sinov for t in self.trad.get(char, []))

    def word_fully_sinov_confirmed(self, word: str) -> bool:
        return all(self.sinov_confirms(ch) for ch in word)

    def word_candidates(self, word: str) -> list[str] | None:
        """Best-effort single Han-Viet reading for a multi-char word, formed
        by picking each character's first candidate. Returns None if any
        character has zero candidates (word needs LLM help / manual review)."""
        parts = []
        for ch in word:
            cands = self.candidates(ch)
            if not cands:
                return None
            parts.append(cands[0])
        return " ".join(parts)
