"""Файл: қоидаҳои филтри сайтҳо аз рӯи синну сол — сатҳҳо, санҷиши доменҳо ва ҳолати телефон.

Худи филтр дар телефони фарзанд кор мекунад (VpnService-и DNS дар Kotlin): сервер танҳо
сатҳ ва рӯйхати сайтҳои манъшударо нигоҳ медорад ва ҳолатеро, ки телефон хабар медиҳад.
"""

import json
import re
from datetime import datetime, timezone
from typing import Optional

from app.core import events as family_events
from app.models.child import Child

# off — филтр нест; kids — то 12 сола (калонсолон, прокси, SafeSearch, YouTube-и маҳдуд);
# teen — 13–17 сола (сайтҳои калонсолон ва SafeSearch).
LEVELS = ("off", "kids", "teen")
# Ҳолатҳое, ки телефони фарзанд хабар медиҳад.
STATES = ("active", "off", "needs_permission", "unsupported")
MAX_BLOCKED = 100

_LABEL = re.compile(r"^(?!-)[a-z0-9-]{1,63}(?<!-)$")


def normalize_domain(raw: str) -> Optional[str]:
    """Суроға ё доменро ба шакли `example.com` меорад; агар нодуруст бошад, None.

    «https://www.YouTube.com/watch?v=1» → «youtube.com». Пешванди «www.» хориҷ мешавад,
    чунки филтр зердоменҳоро ҳам мебандад.
    """
    text = (raw or "").strip().lower()
    text = re.sub(r"^[a-z][a-z0-9+.-]*://", "", text)
    text = re.split(r"[/?#:]", text, maxsplit=1)[0].strip(".")
    if text.startswith("www."):
        text = text[4:]
    try:
        text = text.encode("idna").decode("ascii")
    except UnicodeError:
        return None
    labels = text.split(".")
    if len(text) > 253 or len(labels) < 2 or not all(_LABEL.match(label) for label in labels):
        return None
    if labels[-1].isdigit():  # суроғаи IP домен нест
        return None
    return text


def normalize_blocked(items) -> list:
    """Рӯйхати сайтҳоро тоза мекунад: домени дуруст, бе такрор, ҳадди аксар MAX_BLOCKED."""
    seen = []
    for item in items or []:
        domain = normalize_domain(str(item))
        if domain and domain not in seen:
            seen.append(domain)
    return seen[:MAX_BLOCKED]


def load(child: Child) -> dict:
    """Танзими филтри фарзандро аз база мехонад (ҳамеша бо ҳамаи калидҳо)."""
    data = {}
    if child.web_filter_json:
        try:
            data = json.loads(child.web_filter_json)
        except (TypeError, ValueError):
            data = {}
    level = data.get("level") if data.get("level") in LEVELS else "off"
    return {"level": level, "blocked": normalize_blocked(data.get("blocked"))}


def save(child: Child, level: str, blocked) -> dict:
    """Сатҳ ва рӯйхати сайтҳоро нигоҳ медорад ва танзими тозашударо бармегардонад."""
    if level not in LEVELS:
        raise ValueError("level")
    data = {"level": level, "blocked": normalize_blocked(blocked)}
    child.web_filter_json = json.dumps(data, ensure_ascii=False)
    return data


def payload(child: Child) -> dict:
    """Маълумоти филтр барои snapshot-и барнома: танзим ва ҳолати охирини телефон."""
    reported = child.web_filter_reported_at
    return {
        **load(child),
        "state": child.web_filter_state or None,
        "reported_at": reported.isoformat() if reported else None,
    }


def report_state(db, child: Child, state: str) -> None:
    """Ҳолати филтрро аз телефони фарзанд сабт мекунад.

    Агар волидайн филтрро фаъол карда бошанд ва дар телефон он хомӯш шавад (масалан,
    фарзанд дар танзимот VPN-ро қатъ кард), волидайн як бор огоҳӣ мегиранд.
    """
    if state not in STATES:
        raise ValueError("state")
    previous = child.web_filter_state
    child.web_filter_state = state
    child.web_filter_reported_at = datetime.now(timezone.utc)
    wanted = load(child)["level"] != "off"
    if wanted and state in ("off", "needs_permission") and previous == "active":
        family_events.emit(db, child, "parent", "web_filter_off",
                           f"{child.name}: филтри сайтҳо хомӯш шуд",
                           "Дар телефони фарзанд филтри сайтҳо дигар кор намекунад.",
                           {"state": state})
