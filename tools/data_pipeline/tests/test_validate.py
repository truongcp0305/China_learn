from pipeline.validate import (
    segment_against_vocabulary,
    validate_example,
    validate_han_viet_word,
    validate_meaning_vi,
)


def test_validate_meaning_vi_no_false_positive_on_plain_vietnamese():
    # "nguồn" etc. are all-ASCII-consonant + diacritic-vowel syllables; must
    # not be flagged as leftover English.
    assert validate_meaning_vi("gốc; nguồn gốc") == []
    assert validate_meaning_vi("không có chi") == []


def test_validate_meaning_vi_flags_leftover_english():
    assert "nghĩa có vẻ vẫn còn tiếng Anh" in validate_meaning_vi("to love; to be fond of")


def test_validate_meaning_vi_flags_empty():
    assert validate_meaning_vi("   ") == ["nghĩa rỗng"]


def test_segment_against_vocabulary_finds_oov_span():
    allowed = {"我", "爱", "中国"}
    assert segment_against_vocabulary("我爱中国", allowed) == []
    assert segment_against_vocabulary("我爱北京", allowed) == ["北", "京"]


def test_validate_example_flags_missing_target_and_oov():
    allowed = {"我", "是", "学生"}
    warnings = validate_example("他是老师", "学生", allowed)
    assert any("không chứa từ đích" in w for w in warnings)
    assert any("vượt cấp" in w for w in warnings)


def test_validate_example_clean_sentence_has_no_warnings():
    allowed = {"我", "是", "学生"}
    assert validate_example("我是学生", "学生", allowed) == []


def test_validate_han_viet_word_length_mismatch():
    assert validate_han_viet_word("行长", "hành") == ["số âm Hán Việt (1) khác số chữ (2)"]
    assert validate_han_viet_word("行长", "hành trường") == []
    assert validate_han_viet_word("行长", "") == ["Hán Việt rỗng"]
