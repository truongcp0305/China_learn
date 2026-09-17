from pathlib import Path

from pipeline.importers.dictionaries import (
    normalize_pinyin_numeric,
    parse_cedict_file,
    load_complete_hsk_vocabulary,
    index_complete_hsk_by_simplified,
)

CEDICT_SAMPLE = """# comment line, ignored
國 国 [Guo2] /surname Guo/
國 国 [guo2] /country; nation; state/(bound form) national/
"""

COMPLETE_HSK_SAMPLE = """
[
  {"simplified": "行", "radical": "行", "level": ["new-1", "old-4"], "frequency": 272, "pos": ["v", "n"],
   "forms": [
     {"traditional": "行", "transcriptions": {"pinyin": "háng", "numeric": "hang2"}, "meanings": ["row", "line"], "classifiers": []},
     {"traditional": "行", "transcriptions": {"pinyin": "xíng", "numeric": "xing2"}, "meanings": ["to walk"], "classifiers": []}
   ]}
]
"""


def test_normalize_pinyin_numeric_lowercases_and_collapses_whitespace():
    assert normalize_pinyin_numeric("A1  la1   bo2") == "a1 la1 bo2"
    assert normalize_pinyin_numeric("Guo2") == "guo2"


def test_parse_cedict_file(tmp_path: Path):
    p = tmp_path / "cedict.txt"
    p.write_text(CEDICT_SAMPLE, encoding="utf-8")
    index = parse_cedict_file(p)
    assert ("国", "guo2") in index
    assert ("国", "guo2a") not in index
    entries = index[("国", "guo2")]
    assert entries[0].traditional == "國"
    # Both "Guo2" (surname) and "guo2" (country) normalize to the same key
    # and are kept in file order here — reordering the surname sense out of
    # the way is _meaning_candidates' job (see test_syllabus.py), not the
    # raw parser's.
    assert entries[0].meanings == ["surname Guo"]
    assert entries[1].meanings == ["country; nation; state", "(bound form) national"]


def test_parse_cedict_file_skips_comments(tmp_path: Path):
    p = tmp_path / "cedict.txt"
    p.write_text(CEDICT_SAMPLE, encoding="utf-8")
    index = parse_cedict_file(p)
    total_entries = sum(len(v) for v in index.values())
    assert total_entries == 2  # surname + country sense, comment line ignored


def test_load_complete_hsk_vocabulary(tmp_path: Path):
    p = tmp_path / "complete.json"
    p.write_text(COMPLETE_HSK_SAMPLE, encoding="utf-8")
    words = load_complete_hsk_vocabulary(p)
    assert len(words) == 1
    w = words[0]
    assert w.level_number("new") == 1
    assert w.level_number("old") == 4
    assert w.level_number("newest") is None
    assert [f.pinyin_numeric for f in w.forms] == ["hang2", "xing2"]

    index = index_complete_hsk_by_simplified(words)
    assert index["行"][0] is w
