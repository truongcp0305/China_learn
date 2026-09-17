"""Post-hoc checks on LLM output (plan section 5, B7). These never block a
draft from being written — they only attach human-readable warnings so the
reviewer knows what to double-check, per the plan's "cảnh báo, không tự động
từ chối" approach.
"""
from __future__ import annotations

import re
import string

_ASCII_LETTERS = set(string.ascii_letters)


def segment_against_vocabulary(text: str, allowed: set[str]) -> list[str]:
    """Greedy longest-match segmentation of `text` against `allowed` (a set
    of simplified words/characters). Returns the substrings that could NOT
    be matched — i.e. out-of-vocabulary spans — for the example-sentence
    over-cấp check. Punctuation and whitespace are always allowed."""
    out_of_vocab: list[str] = []
    i, n = 0, len(text)
    max_word_len = max((len(w) for w in allowed), default=1)
    while i < n:
        ch = text[i]
        if not ch.strip() or not ch.isalpha():
            i += 1
            continue
        matched = False
        for length in range(min(max_word_len, n - i), 0, -1):
            if text[i : i + length] in allowed:
                i += length
                matched = True
                break
        if not matched:
            out_of_vocab.append(ch)
            i += 1
    return out_of_vocab


def validate_example(example_zh: str, target_word: str, allowed: set[str]) -> list[str]:
    warnings: list[str] = []
    if not example_zh.strip():
        return ["câu ví dụ rỗng"]
    if target_word not in example_zh:
        warnings.append(f"câu không chứa từ đích '{target_word}'")
    oov = segment_against_vocabulary(example_zh, allowed | {target_word})
    if oov:
        warnings.append(f"từ/chữ có thể vượt cấp: {', '.join(sorted(set(oov)))}")
    if len(example_zh) > 20:
        warnings.append("câu khá dài (>20 chữ), nên rút gọn")
    return warnings


def validate_han_viet_word(simplified: str, han_viet: str) -> list[str]:
    if not han_viet.strip():
        return ["Hán Việt rỗng"]
    syllables = han_viet.split()
    if len(syllables) != len(simplified):
        return [f"số âm Hán Việt ({len(syllables)}) khác số chữ ({len(simplified)})"]
    return []


def validate_meaning_vi(meaning_vi: str) -> list[str]:
    warnings: list[str] = []
    if not meaning_vi.strip():
        return ["nghĩa rỗng"]
    # Almost every real Vietnamese gloss has at least one diacritic vowel
    # (gốc, không, nguồn...); a longer phrase made ENTIRELY of plain ASCII
    # letters is almost always leftover English ("to love; to be fond of")
    # that slipped through instead of a Vietnamese meaning.
    letters = [ch for ch in meaning_vi if ch.isalpha()]
    if len(letters) >= 8 and all(ch in _ASCII_LETTERS for ch in letters):
        warnings.append("nghĩa có vẻ vẫn còn tiếng Anh")
    if len(meaning_vi) > 80:
        warnings.append("nghĩa khá dài, nên rút gọn")
    return warnings
