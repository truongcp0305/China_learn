"""Builds `words` and `chars` rows for one HSK level from the 2025 syllabus
word/char lists, cross-referenced against complete-hsk-vocabulary for pinyin,
and CVDICT/CC-CEDICT for meanings (plan section 2, B2+B3 combined).

The syllabus word list (`HSK_Level_{n}_words.txt`) is just headwords with no
pinyin. A headword with more than one reading in complete-hsk-vocabulary
(e.g. 行 háng/xíng) is genuinely ambiguous at this stage: we pick the first
form as a provisional reading, record every reading as a `pinyin` candidate,
and leave the word markedly for review — never silently guess.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from .dictionaries import (
    CompleteHskWord,
    normalize_pinyin_numeric,
    parse_cedict_file,
    load_complete_hsk_vocabulary,
    index_complete_hsk_by_simplified,
)
from .hanviet import HanVietIndex

from pypinyin import Style, pinyin as pypinyin_convert


_LOW_VALUE_VI_PREFIXES = ("họ ", "biến thể cũ của ", "biến thể của ")


def _meaning_candidates(cvdict, cedict, simplified: str, pinyin_numeric: str) -> list[tuple[str, str]]:
    """Concatenates CVDICT then CC-CEDICT meanings for one (word, reading).

    Both dictionaries list a "surname X" / "old variant of X" sense before
    the everyday meaning for some headwords (和/国/会...) — see 和's CVDICT
    entry for [He2] before [he2]. Since callers auto-pick candidate[0] as
    the draft meaning, push those low-value senses to the back instead of
    dropping them, so the auto-draft favors the useful meaning while a
    reviewer can still recover the surname sense from the candidate list."""
    out: list[tuple[str, str]] = []
    for entry in cvdict.get((simplified, pinyin_numeric), []):
        out.extend((m, "cvdict") for m in entry.meanings)
    for entry in cedict.get((simplified, pinyin_numeric), []):
        out.extend((m, "cedict") for m in entry.meanings)
    out.sort(key=lambda pair: pair[0].lower().startswith(_LOW_VALUE_VI_PREFIXES))
    return out


def _tone_mark_pinyin(word: str) -> str:
    return " ".join(syll[0] for syll in pypinyin_convert(word, style=Style.TONE))


_LOW_VALUE_MEANING_PREFIXES = ("surname ", "old variant of ", "variant of ")


def _pick_primary_form(forms):
    """complete-hsk-vocabulary lists every reading of a headword as a form,
    in no particular frequency order — 和's forms literally start with
    "old variant of 和" before the everyday hé "and" sense. Score each form
    by how many real meanings it has, penalizing surname/variant-of glosses
    that would make a useless auto-picked meaning."""

    def score(f):
        first = (f.meanings[0] if f.meanings else "").lower()
        penalty = 5 if first.startswith(_LOW_VALUE_MEANING_PREFIXES) else 0
        return len(f.meanings) - penalty

    return max(forms, key=score)


def _read_lines(path: Path) -> list[str]:
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


_TRAILING_SENSE_DIGIT = re.compile(r"\d+$")
_PARENS = re.compile(r"[（(]([^）)]*)[）)]")


def headword_lookup_variants(raw: str) -> list[str]:
    """The 2025 syllabus word list marks distinct senses of one character
    with a trailing digit (和1/和2 = two meanings of 和) and writes an
    optional syllable in parens (没（有）, 有（一）点儿). Neither survives a
    direct dictionary lookup, so try, in order: the digit-stripped form with
    the parens content kept (没有), then with the parens content dropped
    (没) — duplicates removed, original order preserved."""
    no_digit = _TRAILING_SENSE_DIGIT.sub("", raw)
    with_content = _PARENS.sub(lambda m: m.group(1), no_digit)
    without_content = _PARENS.sub("", no_digit)
    variants = []
    for v in (no_digit, with_content, without_content):
        if v and v not in variants:
            variants.append(v)
    return variants


@dataclass
class WordCandidate:
    simplified: str
    traditional: str
    pinyin: str
    pinyin_numeric: str
    pos: str
    frequency: int | None
    hsk2_level: int | None
    meaning_en: str | None
    meaning_vi_candidates: list[tuple[str, str]]  # (value, origin)
    pinyin_alternatives: list[str]  # every reading complete-hsk-vocabulary knows, for the chip picker
    ambiguous_reading: bool
    resolved: bool  # False when the headword wasn't found in complete-hsk-vocabulary at all
    raw_headword: str  # exact syllabus text, e.g. "和1" or "没（有）", for the notes column
    notes: str | None = None


@dataclass
class CharCandidate:
    char: str
    traditional: str
    write_level: int | None


@dataclass
class SyllabusData:
    level: int
    words: list[WordCandidate]
    chars: list[CharCandidate]
    unresolved_words: list[str]


def build_level(cfg_raw_dir: Path, level: int) -> SyllabusData:
    syl_dir = cfg_raw_dir / "hsk_syllabus_2025"
    headwords = _read_lines(syl_dir / f"level{level}_words.txt")
    hanzi_list = _read_lines(syl_dir / f"level{level}_hanzi.txt")
    handwritten_set = set(_read_lines(syl_dir / f"level{level}_handwritten.txt"))

    complete_words = load_complete_hsk_vocabulary(cfg_raw_dir / "complete_hsk_vocabulary" / "complete.json")
    by_simplified = index_complete_hsk_by_simplified(complete_words)

    cvdict = parse_cedict_file(cfg_raw_dir / "cvdict" / "CVDICT.u8")
    cedict = parse_cedict_file(cfg_raw_dir / "cc_cedict" / "cedict.txt")

    words: list[WordCandidate] = []
    unresolved: list[str] = []

    for hw in headwords:
        variants = headword_lookup_variants(hw)
        matched_key = next((v for v in variants if v in by_simplified), None)
        note = f"cú pháp gốc trong đề cương: {hw}" if hw != matched_key else None

        if matched_key is not None:
            entries = by_simplified[matched_key]
            # A headword should map to exactly one complete-hsk-vocabulary entry
            # (entries are keyed by simplified text); if the source has more than
            # one, treat every form across all matching entries as a reading option.
            forms = [f for e in entries for f in e.forms]
            primary_entry = entries[0]
            primary_form = _pick_primary_form(forms)

            pinyin_alts = [primary_form.pinyin_numeric]
            for f in forms:
                if f.pinyin_numeric not in pinyin_alts:
                    pinyin_alts.append(f.pinyin_numeric)

            meaning_candidates = _meaning_candidates(cvdict, cedict, matched_key, primary_form.pinyin_numeric)

            words.append(
                WordCandidate(
                    simplified=matched_key,
                    traditional=primary_form.traditional,
                    pinyin=primary_form.pinyin,
                    pinyin_numeric=primary_form.pinyin_numeric,
                    pos=",".join(primary_entry.pos),
                    frequency=primary_entry.frequency,
                    hsk2_level=primary_entry.level_number("old"),
                    meaning_en=primary_form.meanings[0] if primary_form.meanings else None,
                    meaning_vi_candidates=meaning_candidates,
                    pinyin_alternatives=pinyin_alts,
                    ambiguous_reading=len(pinyin_alts) > 1,
                    resolved=True,
                    raw_headword=hw,
                    notes=note,
                )
            )
            continue

        # Not in complete-hsk-vocabulary at all (a handful of fixed phrases
        # like 你好/这个/一下) — fall back to CVDICT/CC-CEDICT directly, which
        # at least gives pinyin + meanings even without pos/frequency/hsk2 tag.
        cv_key = next((v for v in variants if any(k[0] == v for k in cvdict)), None)
        if cv_key is None:
            unresolved.append(hw)
            continue
        cv_entries = [e for k, es in cvdict.items() if k[0] == cv_key for e in es]

        def _cv_score(e):
            first_m = (e.meanings[0] if e.meanings else "").lower()
            penalty = 5 if first_m.startswith(_LOW_VALUE_MEANING_PREFIXES) or first_m.startswith("họ ") else 0
            return len(e.meanings) - penalty

        first = max(cv_entries, key=_cv_score)
        pinyin_alts = [first.pinyin_numeric]
        for e in cv_entries:
            if e.pinyin_numeric not in pinyin_alts:
                pinyin_alts.append(e.pinyin_numeric)
        meaning_candidates = _meaning_candidates(cvdict, cedict, cv_key, first.pinyin_numeric)
        words.append(
            WordCandidate(
                simplified=cv_key,
                traditional=first.traditional,
                pinyin=_tone_mark_pinyin(cv_key),
                pinyin_numeric=first.pinyin_numeric,
                pos="",
                frequency=None,
                hsk2_level=None,
                meaning_en=None,
                meaning_vi_candidates=meaning_candidates,
                pinyin_alternatives=pinyin_alts,
                ambiguous_reading=len(pinyin_alts) > 1,
                resolved=True,
                raw_headword=hw,
                notes=(note or "") + " | không có trong complete-hsk-vocabulary, pinyin lấy từ CVDICT (chưa có dấu thanh dạng chữ)",
            )
        )

    chars: list[CharCandidate] = []
    for ch in hanzi_list:
        entries = by_simplified.get(ch, [])
        traditional = entries[0].forms[0].traditional if entries else ch
        write_level = level if ch in handwritten_set else None
        chars.append(CharCandidate(char=ch, traditional=traditional, write_level=write_level))

    return SyllabusData(level=level, words=words, chars=chars, unresolved_words=unresolved)


def persist(conn, raw_dir: Path, data: SyllabusData) -> dict:
    """Inserts/updates `words`, `chars`, and their `candidates` rows for one
    level. Existing approved fields (meaning_vi, han_viet, example_*) are
    never overwritten — only missing/auto data is refreshed, so re-running
    this after a review pass is always safe."""
    now = datetime.now(timezone.utc).isoformat()
    hv_index = HanVietIndex(raw_dir)
    stats = {"words_inserted": 0, "words_updated": 0, "chars_upserted": 0, "ambiguous": 0, "unresolved": len(data.unresolved_words)}

    for w in data.words:
        row = conn.execute(
            "SELECT id, meaning_status, hsk_level FROM words WHERE simplified=? AND pinyin_numeric=?",
            (w.simplified, w.pinyin_numeric),
        ).fetchone()

        meaning_vi_auto = w.meaning_vi_candidates[0][0] if w.meaning_vi_candidates else None
        meaning_status = "missing" if not w.meaning_vi_candidates else ("auto" if len(w.meaning_vi_candidates) == 1 and not w.ambiguous_reading else "draft")

        han_viet_word = hv_index.word_candidates(w.simplified)
        if han_viet_word and not w.ambiguous_reading and hv_index.word_fully_sinov_confirmed(w.simplified):
            han_viet_status = "auto"
        elif han_viet_word:
            han_viet_status = "draft"  # has a suggestion, but needs a human look
        else:
            han_viet_status = "missing"

        if row is None:
            cur = conn.execute(
                """INSERT INTO words (simplified, traditional, pinyin, pinyin_numeric, pos,
                       hsk_level, hsk2_level, frequency, meaning_en, meaning_vi, meaning_status,
                       han_viet, han_viet_status, notes, updated_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    w.simplified, w.traditional, w.pinyin, w.pinyin_numeric, w.pos,
                    data.level, w.hsk2_level, w.frequency, w.meaning_en, meaning_vi_auto, meaning_status,
                    han_viet_word, han_viet_status, w.notes, now,
                ),
            )
            word_id = cur.lastrowid
            stats["words_inserted"] += 1
        else:
            # Same (simplified, pinyin_numeric) already imported at another
            # level. The 2025 syllabus reuses a headword across levels when
            # it teaches a *different sense* at the higher level (点 "o'clock"
            # at L1, 点 "to order food" at L3 — both diǎn, one dictionary
            # entry) — it is not a duplicate. Keep the word at the level it
            # first appeared (spaced repetition should introduce it then),
            # and just note that a later level adds another sense.
            word_id = row["id"]
            if data.level > row["hsk_level"]:
                extra_note = f"nghĩa khác của từ này xuất hiện lại ở HSK{data.level} (đánh dấu '{w.raw_headword}')"
                conn.execute(
                    "UPDATE words SET notes = CASE WHEN notes IS NULL OR notes='' THEN ? ELSE notes || ' | ' || ? END WHERE id=?",
                    (extra_note, extra_note, word_id),
                )
                stats["words_reappeared_higher_level"] = stats.get("words_reappeared_higher_level", 0) + 1
            else:
                # Only backfill fields that are still missing/auto, never touch approved/draft-in-review data.
                if row["meaning_status"] in ("missing",):
                    conn.execute(
                        "UPDATE words SET meaning_vi=?, meaning_status=?, updated_at=? WHERE id=?",
                        (meaning_vi_auto, meaning_status, now, word_id),
                    )
                conn.execute(
                    "UPDATE words SET traditional=?, pinyin=?, pos=?, hsk2_level=?, frequency=?, meaning_en=?, notes=? WHERE id=?",
                    (w.traditional, w.pinyin, w.pos, w.hsk2_level, w.frequency, w.meaning_en, w.notes, word_id),
                )
                stats["words_updated"] += 1

        conn.execute("DELETE FROM candidates WHERE entity_type='word' AND entity_id=? AND field IN ('pinyin','meaning_vi')", (str(word_id),))
        for i, p in enumerate(w.pinyin_alternatives):
            conn.execute(
                "INSERT INTO candidates (entity_type, entity_id, field, value, origin, rank) VALUES ('word', ?, 'pinyin', ?, 'complete_hsk_vocabulary', ?)",
                (str(word_id), p, i),
            )
        for i, (val, origin) in enumerate(w.meaning_vi_candidates):
            conn.execute(
                "INSERT INTO candidates (entity_type, entity_id, field, value, origin, rank) VALUES ('word', ?, 'meaning_vi', ?, ?, ?)",
                (str(word_id), val, origin, i),
            )
        if w.ambiguous_reading:
            stats["ambiguous"] += 1

    for c in data.chars:
        cands = hv_index.candidates(c.char)
        if len(cands) == 1 and hv_index.sinov_confirms(c.char):
            han_viet_auto, status = cands[0], "auto"
        elif cands:
            han_viet_auto, status = cands[0], "draft"  # suggestion present, needs a human look
        else:
            han_viet_auto, status = None, "missing"
        existing = conn.execute("SELECT han_viet_status FROM chars WHERE char=?", (c.char,)).fetchone()
        if existing is None:
            conn.execute(
                "INSERT INTO chars (char, traditional, hsk_level, write_level, han_viet, han_viet_status, updated_at) VALUES (?,?,?,?,?,?,?)",
                (c.char, c.traditional, data.level, c.write_level, han_viet_auto, status, now),
            )
        else:
            if existing["han_viet_status"] == "missing" and han_viet_auto:
                conn.execute("UPDATE chars SET han_viet=?, han_viet_status=? WHERE char=?", (han_viet_auto, status, c.char))
            conn.execute("UPDATE chars SET traditional=?, hsk_level=?, write_level=?, updated_at=? WHERE char=?",
                         (c.traditional, data.level, c.write_level, now, c.char))
        conn.execute("DELETE FROM candidates WHERE entity_type='char' AND entity_id=? AND field='han_viet'", (c.char,))
        for i, v in enumerate(cands):
            conn.execute(
                "INSERT INTO candidates (entity_type, entity_id, field, value, origin, rank) VALUES ('char', ?, 'han_viet', ?, 'sinov_unihan', ?)",
                (c.char, v, i),
            )
        stats["chars_upserted"] += 1

    conn.commit()
    return stats
