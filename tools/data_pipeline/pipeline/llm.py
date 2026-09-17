"""Thin client for LM Studio's OpenAI-compatible API (plan section 5, B6).

LM Studio only accepts `response_format.type` of `json_schema` or `text`
(not the OpenAI `json_object` shortcut), and honors `strict: true` schemas —
tested manually against qwen/qwen3.5-9b before writing this.
"""
from __future__ import annotations

import json

import httpx

from .config import Config


class LlmError(RuntimeError):
    pass


class LmStudioClient:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.client = httpx.Client(base_url=cfg.llm_base_url, timeout=cfg.llm_timeout_seconds)

    def list_models(self) -> list[str]:
        resp = self.client.get("/models")
        resp.raise_for_status()
        return [m["id"] for m in resp.json()["data"]]

    def chat_json(self, model: str, system: str, user: str, schema_name: str, schema: dict) -> tuple[dict, str]:
        """Returns (parsed_json, raw_content). Retries on transport errors and
        on JSON that fails to parse or doesn't match the schema's top-level
        shape; never retries on a well-formed-but-"wrong" answer — that's a
        content problem for the reviewer, not a transport problem."""
        body = {
            "model": model,
            "temperature": self.cfg.llm_temperature,
            "max_tokens": 4000,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {"name": schema_name, "strict": True, "schema": schema},
            },
        }
        if self.cfg.llm_thinking:
            body["chat_template_kwargs"] = {"enable_thinking": True}

        last_err: Exception | None = None
        for attempt in range(self.cfg.llm_max_retries + 1):
            try:
                resp = self.client.post("/chat/completions", json=body)
                resp.raise_for_status()
                data = resp.json()
                content = data["choices"][0]["message"]["content"]
                parsed = json.loads(content)
                return parsed, content
            except (httpx.HTTPError, KeyError, json.JSONDecodeError) as e:
                last_err = e
                continue
        raise LlmError(f"LM Studio call failed after {self.cfg.llm_max_retries + 1} attempts: {last_err}")

    def close(self) -> None:
        self.client.close()
