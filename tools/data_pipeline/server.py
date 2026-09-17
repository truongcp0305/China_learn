"""FastAPI app for the HSK data-pipeline review UI (plan section 6, M2).

Run with:
    .venv/Scripts/python -m uvicorn server:app --reload --port 8765

Binds to 127.0.0.1 only (see config.toml `server.host`) — this is a local
tool for one reviewer, not a service exposed to the network.
"""
from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from pipeline import batches as batches_mod
from pipeline import repo
from pipeline.config import load_config
from pipeline.db import connect, init_db
from pipeline.export import export_levels
from pipeline.llm import LlmError, LmStudioClient

ROOT = Path(__file__).resolve().parent
cfg = load_config()
init_db(cfg.db_path)  # make sure schema exists even if fetch/import never ran
cfg.dist_dir.mkdir(parents=True, exist_ok=True)
(cfg.dist_dir / "packs").mkdir(parents=True, exist_ok=True)

app = FastAPI(title="HSK data pipeline")

# --serve_packs_on_lan lets a phone on the same LAN fetch the exported
# packs (see plan B10) without opening up the review API: if the server is
# bound to 0.0.0.0, every request NOT for /manifest.json or /packs/* from a
# non-loopback client is refused here, before it reaches a route.
if cfg.serve_packs_on_lan:
    _ALLOWED_LAN_PREFIXES = ("/manifest.json", "/packs/")

    @app.middleware("http")
    async def _restrict_lan_to_packs(request: Request, call_next):
        client_host = request.client.host if request.client else ""
        if client_host not in ("127.0.0.1", "::1") and not request.url.path.startswith(_ALLOWED_LAN_PREFIXES):
            return JSONResponse({"detail": "chỉ /manifest.json và /packs/* được phục vụ qua LAN"}, status_code=403)
        return await call_next(request)

app.mount("/packs", StaticFiles(directory=str(cfg.dist_dir / "packs")), name="packs")


def get_conn():
    # One short-lived connection per request is fine at this scale (a single
    # local reviewer clicking through a few hundred rows).
    return connect(cfg.db_path)


@app.get("/")
def index():
    return FileResponse(ROOT / "web" / "index.html")


@app.get("/manifest.json")
def manifest():
    path = cfg.dist_dir / "manifest.json"
    if not path.exists():
        raise HTTPException(404, "chưa xuất gói nào — chạy export trước")
    return FileResponse(path)


@app.get("/api/overview")
def api_overview():
    conn = get_conn()
    try:
        return repo.overview(conn)
    finally:
        conn.close()


@app.get("/api/words")
def api_list_words(level: int, status: str | None = None, field: str = "meaning_vi", limit: int = 50, offset: int = 0):
    conn = get_conn()
    try:
        return repo.list_words(conn, level, status, field, limit, offset)
    finally:
        conn.close()


@app.get("/api/chars")
def api_list_chars(level: int, status: str | None = None, limit: int = 50, offset: int = 0):
    conn = get_conn()
    try:
        return repo.list_chars(conn, level, status, limit, offset)
    finally:
        conn.close()


class WordPatch(BaseModel):
    pinyin: str | None = None
    meaning_vi: str | None = None
    han_viet: str | None = None
    example_zh: str | None = None
    example_pinyin: str | None = None
    example_vi: str | None = None
    notes: str | None = None
    meaning_status: str | None = None
    han_viet_status: str | None = None
    example_status: str | None = None


@app.patch("/api/words/{word_id}")
def api_update_word(word_id: int, patch: WordPatch):
    conn = get_conn()
    try:
        data = {k: v for k, v in patch.model_dump().items() if v is not None}
        try:
            return repo.update_word(conn, word_id, data, actor="reviewer")
        except KeyError as e:
            raise HTTPException(404, str(e))
    finally:
        conn.close()


class ApproveBody(BaseModel):
    field: str  # meaning_vi | han_viet | example
    value: str | None = None


@app.post("/api/words/{word_id}/approve")
def api_approve_word(word_id: int, body: ApproveBody):
    conn = get_conn()
    try:
        try:
            return repo.approve_word_field(conn, word_id, body.field, body.value, actor="reviewer")
        except KeyError as e:
            raise HTTPException(404, str(e))
    finally:
        conn.close()


class CharPatch(BaseModel):
    han_viet: str | None = None
    han_viet_status: str | None = None


@app.patch("/api/chars/{char}")
def api_update_char(char: str, patch: CharPatch):
    conn = get_conn()
    try:
        data = {k: v for k, v in patch.model_dump().items() if v is not None}
        try:
            return repo.update_char(conn, char, data, actor="reviewer")
        except KeyError as e:
            raise HTTPException(404, str(e))
    finally:
        conn.close()


@app.post("/api/chars/{char}/approve")
def api_approve_char(char: str):
    conn = get_conn()
    try:
        try:
            return repo.update_char(conn, char, {"han_viet_status": "approved"}, actor="reviewer")
        except KeyError as e:
            raise HTTPException(404, str(e))
    finally:
        conn.close()


@app.get("/api/llm/models")
def api_llm_models():
    client = LmStudioClient(cfg)
    try:
        return {"models": client.list_models(), "default": cfg.llm_default_model}
    except Exception as e:  # noqa: BLE001 - surfaced to the UI as a plain message
        raise HTTPException(502, f"Không kết nối được LM Studio tại {cfg.llm_base_url}: {e}")
    finally:
        client.close()


class RunBatchBody(BaseModel):
    kind: str  # meaning_vi | han_viet | example
    entity_type: str = "word"  # word | char (char only used with kind=han_viet)
    level: int
    size: int = 20
    model: str


@app.post("/api/batches/run")
def api_run_batch(body: RunBatchBody):
    conn = get_conn()
    try:
        try:
            return batches_mod.run_batch(conn, cfg, body.kind, body.entity_type, body.level, body.size, body.model)
        except LlmError as e:
            raise HTTPException(502, str(e))
        except ValueError as e:
            raise HTTPException(400, str(e))
    finally:
        conn.close()


@app.get("/api/batches")
def api_list_batches(limit: int = 20):
    conn = get_conn()
    try:
        rows = conn.execute("SELECT * FROM batches ORDER BY id DESC LIMIT ?", (limit,)).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


class ExportBody(BaseModel):
    levels: list[int]


@app.post("/api/export")
def api_export(body: ExportBody):
    conn = get_conn()
    try:
        return export_levels(conn, cfg, body.levels)
    finally:
        conn.close()


@app.get("/api/pack_versions")
def api_pack_versions():
    conn = get_conn()
    try:
        rows = conn.execute("SELECT * FROM pack_versions ORDER BY level").fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


@app.get("/api/batches/{batch_id}")
def api_get_batch(batch_id: int):
    conn = get_conn()
    try:
        batch = conn.execute("SELECT * FROM batches WHERE id=?", (batch_id,)).fetchone()
        if batch is None:
            raise HTTPException(404, "batch not found")
        items = conn.execute("SELECT * FROM batch_items WHERE batch_id=? ORDER BY id", (batch_id,)).fetchall()
        return {"batch": dict(batch), "items": [dict(i) for i in items]}
    finally:
        conn.close()
