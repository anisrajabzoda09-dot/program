"""Файл: қоидаҳои барномаҳо аз рӯи ҷой ва огоҳии «расид / баромад».

Волидайн барои ҳар ҷой (масалан «Мактаб») метавонанд барномаҳоро баста, бо лимит ё ҳамеша
кушода гузоранд. Худи қоидаҳо дар телефони фарзанд иҷро мешаванд (бе интернет ҳам); сервер
онҳоро нигоҳ медорад ва аз рӯи макони фиристодашуда огоҳии омадан ва рафтанро медиҳад.
"""

import json
import math
from typing import Optional

from app.core import events as family_events

MODES = ("block", "limit", "allow")
MAX_APPS = 300
MIN_LIMIT, MAX_LIMIT = 5, 720
# Барои он ки GPS дар канори ҷой «расид/баромад»-и бепоён надиҳад: баромадан танҳо пас аз
# ин қадар метр берун аз радиус ҳисоб мешавад.
LEAVE_MARGIN_METERS = 40
# Нуқтаҳое, ки дақиқиашон аз ин бадтар аст, ҷойро иваз намекунанд.
MAX_ACCURACY_METERS = 150


def normalize_rules(raw) -> dict:
    """Қоидаҳои ҷойро тоза мекунад: танҳо навъҳои маълум, лимит 5–720 дақ, ҳадди аксар 300 барнома."""
    raw = raw if isinstance(raw, dict) else {}
    apps = {}
    for package, rule in list((raw.get("apps") or {}).items())[:MAX_APPS]:
        if not isinstance(package, str) or not package or len(package) > 200 or not isinstance(rule, dict):
            continue
        mode = rule.get("mode")
        if mode not in MODES:
            continue
        item = {"mode": mode}
        if mode == "limit":
            try:
                minutes = int(rule.get("minutes"))
            except (TypeError, ValueError):
                continue
            item["minutes"] = max(MIN_LIMIT, min(MAX_LIMIT, minutes))
        apps[package] = item
    return {"apps": apps, "notify": bool(raw.get("notify", False))}


def load_rules(place) -> dict:
    """Қоидаҳои ҷойро аз база мехонад (ҳамеша бо ҳамаи калидҳо)."""
    try:
        return normalize_rules(json.loads(place.rules_json or "{}"))
    except (TypeError, ValueError):
        return normalize_rules({})


def distance_meters(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Масофаи байни ду нуқта бо метр (формулаи haversine)."""
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def place_at(lat: float, lng: float, places, current_id: Optional[int] = None):
    """Ҷойеро, ки нуқта дар он аст, бармегардонад (наздиктаринашро).

    Агар фарзанд аллакай дар ҷойи current_id бошад, то LEAVE_MARGIN_METERS берун аз радиус
    ҳоло ҳам дар ҳамон ҷой ҳисоб мешавад.
    """
    for place in places:
        if place.id == current_id:
            if distance_meters(lat, lng, place.latitude, place.longitude) <= place.radius_meters + LEAVE_MARGIN_METERS:
                return place
    best, best_d = None, float("inf")
    for place in places:
        d = distance_meters(lat, lng, place.latitude, place.longitude)
        if d <= place.radius_meters and d < best_d:
            best, best_d = place, d
    return best


def on_location(db, child, places, lat: float, lng: float, accuracy: Optional[float]) -> None:
    """Пас аз макони нав ҷойи ҳозираро нав мекунад ва огоҳии «расид / баромад»-ро мефиристад."""
    if accuracy is not None and accuracy > MAX_ACCURACY_METERS:
        return
    by_id = {p.id: p for p in places}
    previous = by_id.get(child.current_place_id)
    current = place_at(lat, lng, places, child.current_place_id if previous else None)
    new_id = current.id if current else None
    if new_id == (previous.id if previous else None):
        if child.current_place_id is not None and previous is None:
            child.current_place_id = None  # ҷой нест карда шуд
        return
    if previous is not None and load_rules(previous)["notify"]:
        family_events.emit(db, child, "parent", "place_leave", f"{child.name} аз «{previous.name}» баромад",
                           "", {"place": previous.name, "place_id": previous.id})
    if current is not None and load_rules(current)["notify"]:
        family_events.emit(db, child, "parent", "place_arrive", f"{child.name} ба «{current.name}» расид",
                           "", {"place": current.name, "place_id": current.id})
    child.current_place_id = new_id
