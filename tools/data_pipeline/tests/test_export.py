from pathlib import Path

from pipeline.config import Config
from pipeline.db import init_db
from pipeline.export import build_pack, write_pack, write_manifest, export_levels


def _cfg(tmp_path: Path) -> Config:
    return Config(
        llm_base_url="http://127.0.0.1:1234/v1", llm_default_model="", llm_temperature=0.2,
        llm_timeout_seconds=30, llm_max_retries=1, llm_thinking=False,
        server_host="127.0.0.1", server_port=8765, serve_packs_on_lan=False,
        raw_dir=tmp_path / "raw", db_path=tmp_path / "master.sqlite",
        backups_dir=tmp_path / "backups", snapshots_dir=tmp_path / "snapshots",
        dist_dir=tmp_path / "dist",
    )


def _seed(conn, now="2026-01-01T00:00:00+00:00"):
    conn.execute(
        """INSERT INTO words (simplified, traditional, pinyin, pinyin_numeric, pos, hsk_level,
             meaning_vi, meaning_status, han_viet, han_viet_status, example_zh, example_status, updated_at)
           VALUES ('爱','愛','ài','ai4','v',1,'yêu; thích','approved','ái','approved',NULL,'missing',?)""",
        (now,),
    )
    conn.execute(
        """INSERT INTO words (simplified, traditional, pinyin, pinyin_numeric, pos, hsk_level,
             meaning_vi, meaning_status, han_viet, han_viet_status, updated_at)
           VALUES ('吧','吧','ba','ba5','y',1,'trợ từ','draft',NULL,'missing',?)""",
        (now,),
    )
    conn.execute("INSERT INTO chars (char, traditional, hsk_level, han_viet, han_viet_status, updated_at) VALUES ('爱','愛',1,'ái','approved',?)", (now,))
    conn.execute("INSERT INTO chars (char, traditional, hsk_level, han_viet, han_viet_status, updated_at) VALUES ('吧','吧',1,'ba','draft',?)", (now,))
    conn.commit()


def test_build_pack_only_includes_approved_meaning(tmp_path: Path):
    cfg = _cfg(tmp_path)
    conn = init_db(cfg.db_path)
    _seed(conn)

    pack, report = build_pack(conn, 1)
    assert [w["simplified"] for w in pack["words"]] == ["爱"]  # 吧's meaning is still draft
    assert report["words_included"] == 1
    assert report["words_skipped"] == 1
    assert pack["words"][0]["han_viet"] == "ái"

    chars = {c["char"]: c for c in pack["chars"]}
    assert chars["爱"]["han_viet"] == "ái"
    assert "han_viet" not in chars["吧"]  # draft, not approved -> field omitted but char itself still listed


def test_write_pack_version_bumps_only_on_content_change(tmp_path: Path):
    cfg = _cfg(tmp_path)
    conn = init_db(cfg.db_path)
    _seed(conn)

    r1 = write_pack(conn, cfg, 1)
    assert r1["version"] == 1
    assert r1["changed"] is True
    assert (cfg.dist_dir / "packs" / "hsk1.json").exists()

    r2 = write_pack(conn, cfg, 1)
    assert r2["version"] == 1
    assert r2["changed"] is False  # nothing changed since r1

    conn.execute("UPDATE words SET meaning_status='approved' WHERE simplified='吧'")
    conn.commit()
    r3 = write_pack(conn, cfg, 1)
    assert r3["version"] == 2
    assert r3["changed"] is True


def test_export_levels_writes_manifest_with_all_levels(tmp_path: Path):
    cfg = _cfg(tmp_path)
    conn = init_db(cfg.db_path)
    _seed(conn)

    export_levels(conn, cfg, [1])
    import json
    manifest = json.loads((cfg.dist_dir / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["packs"][0]["level"] == 1
    assert manifest["packs"][0]["file"] == "packs/hsk1.json"
    assert "sha256" in manifest["packs"][0]
