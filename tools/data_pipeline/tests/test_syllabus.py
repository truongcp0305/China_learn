from pathlib import Path

from pipeline.importers.syllabus import headword_lookup_variants, _pick_primary_form, _meaning_candidates
from pipeline.importers.dictionaries import CompleteHskForm, parse_cedict_file


def test_headword_lookup_variants_trailing_digit():
    assert headword_lookup_variants("和1") == ["和"]
    assert headword_lookup_variants("点3") == ["点"]


def test_headword_lookup_variants_no_annotation_is_unchanged():
    assert headword_lookup_variants("爱") == ["爱"]


def test_headword_lookup_variants_parens_optional_syllable():
    variants = headword_lookup_variants("没（有）")
    assert variants == ["没（有）", "没有", "没"]


def test_headword_lookup_variants_ascii_parens_and_digit_combined():
    variants = headword_lookup_variants("有(一)点儿2")
    assert variants == ["有(一)点儿", "有一点儿", "有点儿"]


def _form(pinyin_numeric: str, meanings: list[str]) -> CompleteHskForm:
    return CompleteHskForm(
        traditional="x", pinyin=pinyin_numeric, pinyin_numeric=pinyin_numeric,
        meanings=meanings, classifiers=[],
    )


def test_pick_primary_form_avoids_old_variant_and_surname_glosses():
    forms = [
        _form("he2", ["old variant of 和", "harmonious"]),
        _form("he2b", ["surname He"]),
        _form("he2c", ["and; together with", "sum", "harmonious"]),
    ]
    assert _pick_primary_form(forms).pinyin_numeric == "he2c"


def test_pick_primary_form_falls_back_to_most_meanings_when_no_penalty_applies():
    forms = [_form("a", ["one meaning"]), _form("b", ["meaning one", "meaning two"])]
    assert _pick_primary_form(forms).pinyin_numeric == "b"


def test_meaning_candidates_pushes_surname_sense_to_the_back(tmp_path: Path):
    # Mirrors CVDICT's real 国 entry: "Guo2"/surname listed before "guo2"/country.
    cv = tmp_path / "cv.txt"
    cv.write_text(
        "國 国 [Guo2] /họ [Guo2]/\n國 国 [guo2] /quốc gia; dân tộc; nhà nước/\n",
        encoding="utf-8",
    )
    ce = tmp_path / "ce.txt"
    ce.write_text("", encoding="utf-8")
    cvdict = parse_cedict_file(cv)
    cedict = parse_cedict_file(ce)

    candidates = _meaning_candidates(cvdict, cedict, "国", "guo2")
    assert candidates[0][0] == "quốc gia; dân tộc; nhà nước"
    assert candidates[-1][0] == "họ [Guo2]"
