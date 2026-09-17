from pathlib import Path

from pipeline.importers.hanviet import (
    load_sinov,
    load_unihan_vietnamese,
    load_unihan_traditional_variants,
    HanVietIndex,
)

SINOV_SAMPLE = "汉字,漢越語,IPA\n行,Hành,x\n行,Hàng,y\n长,Trường,z\n"

UNIHAN_READINGS_SAMPLE = "U+884C\tkVietnamese\thạnh\nU+9577\tkVietnamese\ttrường trưởng\n"
UNIHAN_VARIANTS_SAMPLE = "U+957F\tkTraditionalVariant\tU+9577\n"  # 长 -> 長


def test_load_sinov_dedupes_and_lowercases(tmp_path: Path):
    p = tmp_path / "sinov.csv"
    p.write_text(SINOV_SAMPLE, encoding="utf-8")
    idx = load_sinov(p)
    assert idx["行"] == ["hành", "hàng"]


def test_load_sinov_splits_glued_parenthetical_reading(tmp_path: Path):
    # Real sinov data quality bug: 西 is stored as one row "Tê (Tây)" instead
    # of two rows. Must become two clean candidates, not one glued string.
    p = tmp_path / "sinov.csv"
    p.write_text("汉字,漢越語,IPA\n西,Tê (Tây),te1\n", encoding="utf-8")
    idx = load_sinov(p)
    assert idx["西"] == ["tê", "tây"]


def test_load_unihan_vietnamese(tmp_path: Path):
    p = tmp_path / "Unihan_Readings.txt"
    p.write_text(UNIHAN_READINGS_SAMPLE, encoding="utf-8")
    idx = load_unihan_vietnamese(p)
    assert idx["行"] == ["hạnh"]
    assert idx["長"] == ["trường", "trưởng"]


def test_han_viet_index_merges_and_resolves_traditional(tmp_path: Path):
    raw = tmp_path / "raw"
    (raw / "sinov").mkdir(parents=True)
    (raw / "unihan").mkdir(parents=True)
    (raw / "sinov" / "sino-vietnamese-readings.csv").write_text(SINOV_SAMPLE, encoding="utf-8")
    (raw / "unihan" / "Unihan_Readings.txt").write_text(UNIHAN_READINGS_SAMPLE, encoding="utf-8")
    (raw / "unihan" / "Unihan_Variants.txt").write_text(UNIHAN_VARIANTS_SAMPLE, encoding="utf-8")

    idx = HanVietIndex(raw)
    # 行: sinov has hành/hàng directly, unihan adds hạnh -> union, sinov order first
    assert idx.candidates("行") == ["hành", "hàng", "hạnh"]
    # 长 (simplified): no direct entry, but traditional variant 長 has trường/trưởng
    assert idx.candidates("长") == ["trường", "trưởng"]
    # word candidate needs every char to resolve to exactly... here it just picks first
    assert idx.word_candidates("行长") == "hành trường"


def test_sinov_confirms_false_for_unihan_only_char(tmp_path: Path):
    # Mirrors the real 们 case: Unihan's kVietnamese returns a Nom reading
    # ("món") with no sinov entry to back it up — must not be auto-approved.
    raw = tmp_path / "raw"
    (raw / "sinov").mkdir(parents=True)
    (raw / "unihan").mkdir(parents=True)
    (raw / "sinov" / "sino-vietnamese-readings.csv").write_text("汉字,漢越語,IPA\n", encoding="utf-8")
    (raw / "unihan" / "Unihan_Readings.txt").write_text("U+4EEC\tkVietnamese\tmon\n", encoding="utf-8")
    (raw / "unihan" / "Unihan_Variants.txt").write_text("", encoding="utf-8")

    idx = HanVietIndex(raw)
    assert idx.candidates("们") == ["mon"]
    assert idx.sinov_confirms("们") is False
    assert idx.word_fully_sinov_confirmed("们") is False


def test_han_viet_index_word_candidates_none_when_char_unresolved(tmp_path: Path):
    raw = tmp_path / "raw"
    (raw / "sinov").mkdir(parents=True)
    (raw / "unihan").mkdir(parents=True)
    (raw / "sinov" / "sino-vietnamese-readings.csv").write_text("汉字,漢越語,IPA\n", encoding="utf-8")
    (raw / "unihan" / "Unihan_Readings.txt").write_text("", encoding="utf-8")
    (raw / "unihan" / "Unihan_Variants.txt").write_text("", encoding="utf-8")

    idx = HanVietIndex(raw)
    assert idx.word_candidates("行") is None
