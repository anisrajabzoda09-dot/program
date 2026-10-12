"""Gemini integration that keeps the API key and family data on the server."""

import json
from typing import Any

import httpx

from app.core.config import settings


class GeminiUnavailable(RuntimeError):
    """Gemini is not configured or did not return a usable response."""


def _extract_json(payload: dict) -> dict:
    try:
        text = payload["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError, TypeError, AttributeError) as exc:
        raise GeminiUnavailable("Gemini ҷавоби дуруст надод") from exc
    if text.startswith("```"):
        text = text.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise GeminiUnavailable("Gemini JSON-и дуруст надод") from exc
    if not isinstance(value, dict):
        raise GeminiUnavailable("Gemini объекти JSON надод")
    return value


def generate_json(prompt: str, schema: dict[str, Any]) -> dict:
    """Calls Gemini with structured output; secrets never leave the server."""

    key = settings.GEMINI_API_KEY.strip()
    if not key:
        raise GeminiUnavailable("NIGOH AI ҳоло дар сервер фаъол нашудааст")
    endpoint = (
        f"{settings.GEMINI_API_URL.rstrip('/')}/models/"
        f"{settings.GEMINI_MODEL}:generateContent"
    )
    body = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json",
            "responseJsonSchema": schema,
        },
    }
    try:
        response = httpx.post(
            endpoint,
            headers={"x-goog-api-key": key, "Content-Type": "application/json"},
            json=body,
            timeout=settings.GEMINI_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        return _extract_json(response.json())
    except httpx.HTTPError as exc:
        raise GeminiUnavailable("NIGOH AI муваққатан дастнорас аст") from exc
