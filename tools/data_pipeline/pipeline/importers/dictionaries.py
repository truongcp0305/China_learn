"""Parsers for the three word-level sources: CVDICT, CC-CEDICT, and
drkameleon/complete-hsk-vocabulary's complete.json (see plan section 2, B3).

CVDICT and CC-CEDICT share the classic CEDICT line format:

    TRADITIONAL SIMPLIFIED [pinyin numeric] /meaning 1/meaning 2/.../

`complete.json` groups all readings of one headword into a single entry with
a `forms` list, one form per (traditional variant, pinyin) pair.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

_CEDICT_LINE = re.compile(
    r"^(?P<trad>\S+)\s+(?P<simp>\S+)\s+\[(?P<pinyin>[^\]]+)\]\s+/(?P<meanings>.+)/\s*$"
)


def normalize_pinyin_numeric(s: str) -> str:
    """Lowercases and collapses whitespace so CVDICT/CEDICT ("le5") and
    complete.json ("A1 la1 bo2 yu3") numeric pinyin compare equal."""
    return " ".join(s.lower().split())


@dataclass
class CedictEntry:
    traditional: str
    simplified: str
    pinyin_numeric: str
    meanings: list[str]


def parse_cedict_file(path: Path) -> dict[tuple[str, str], list[CedictEntry]]:
    """Returns {(simplified, normalized_pinyin_numeric): [entries]} — a list
    because a handful of headwords (rare variant readings) repeat the same
    key with different meanings; callers should concatenate them in order."""
    index: dict[tuple[str, str], list[CedictEntry]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        m = _CEDICT_LINE.match(line)
        if not m:
            continue
        pinyin_norm = normalize_pinyin_numeric(m.group("pinyin"))
        entry = CedictEntry(
            traditional=m.group("trad"),
            simplified=m.group("simp"),
            pinyin_numeric=pinyin_norm,
            meanings=[x for x in m.group("meanings").split("/") if x],
        )
        index.setdefault((entry.simplified, pinyin_norm), []).append(entry)
    return index


@dataclass
class CompleteHskForm:
    traditional: str
    pinyin: str
    pinyin_numeric: str
    meanings: list[str]
    classifiers: list[str]


@dataclass
class CompleteHskWord:
    simplified: str
    radical: str
    levels: list[str]  # e.g. ["newest-3", "new-1", "old-4"]
    frequency: int | None
    pos: list[str]
    forms: list[CompleteHskForm]

    def level_number(self, prefix: str) -> int | None:
        """`prefix` is 'new' (HSK 3.0 draft used by krmanik 2025 data),
        'newest', or 'old' (HSK 2.0). Returns the level int if tagged."""
        for lv in self.levels:
            if lv.startswith(prefix + "-"):
                return int(lv.split("-")[1])
        return None


def load_complete_hsk_vocabulary(path: Path) -> list[CompleteHskWord]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    words: list[CompleteHskWord] = []
    for e in raw:
        forms = [
            CompleteHskForm(
                traditional=f["traditional"],
                pinyin=f["transcriptions"]["pinyin"],
                pinyin_numeric=normalize_pinyin_numeric(f["transcriptions"]["numeric"]),
                meanings=f.get("meanings", []),
                classifiers=f.get("classifiers", []),
            )
            for f in e.get("forms", [])
        ]
        words.append(
            CompleteHskWord(
                simplified=e["simplified"],
                radical=e.get("radical", ""),
                levels=e.get("level", []),
                frequency=e.get("frequency"),
                pos=e.get("pos", []),
                forms=forms,
            )
        )
    return words


def index_complete_hsk_by_simplified(
    words: list[CompleteHskWord],
) -> dict[str, list[CompleteHskWord]]:
    index: dict[str, list[CompleteHskWord]] = {}
    for w in words:
        index.setdefault(w.simplified, []).append(w)
    return index
