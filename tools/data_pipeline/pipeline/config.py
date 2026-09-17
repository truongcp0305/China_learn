"""Loads config.toml once and exposes it as a plain dict-ish namespace."""
from __future__ import annotations

import tomllib
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


@dataclass
class Source:
    name: str
    license: str
    repo: str | None = None
    ref: str | None = None
    file: str | None = None
    url: str | None = None


@dataclass
class Config:
    llm_base_url: str
    llm_default_model: str
    llm_temperature: float
    llm_timeout_seconds: int
    llm_max_retries: int
    llm_thinking: bool
    server_host: str
    server_port: int
    serve_packs_on_lan: bool
    raw_dir: Path
    db_path: Path
    backups_dir: Path
    snapshots_dir: Path
    dist_dir: Path
    sources: dict[str, Source] = field(default_factory=dict)

    def source(self, name: str) -> Source:
        return self.sources[name]


def load_config(path: Path | None = None) -> Config:
    path = path or (ROOT / "config.toml")
    with open(path, "rb") as f:
        raw = tomllib.load(f)

    def resolve(p: str) -> Path:
        pp = Path(p)
        return pp if pp.is_absolute() else ROOT / pp

    sources = {s["name"]: Source(**s) for s in raw.get("sources", [])}

    return Config(
        llm_base_url=raw["llm"]["base_url"],
        llm_default_model=raw["llm"].get("default_model", ""),
        llm_temperature=raw["llm"].get("temperature", 0.2),
        llm_timeout_seconds=raw["llm"].get("timeout_seconds", 120),
        llm_max_retries=raw["llm"].get("max_retries", 2),
        llm_thinking=raw["llm"].get("thinking", False),
        server_host=raw["server"]["host"],
        server_port=raw["server"]["port"],
        serve_packs_on_lan=raw["server"].get("serve_packs_on_lan", False),
        raw_dir=resolve(raw["paths"]["raw_dir"]),
        db_path=resolve(raw["paths"]["db_path"]),
        backups_dir=resolve(raw["paths"]["backups_dir"]),
        snapshots_dir=resolve(raw["paths"]["snapshots_dir"]),
        dist_dir=resolve(raw["paths"]["dist_dir"]),
        sources=sources,
    )
