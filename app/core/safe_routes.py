"""Санҷиши масири бехатар бо тасдиқи ду нуқтаи GPS ва огоҳии дермонӣ."""

import json
import math
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from app.core import events as family_events
from app.core.place_rules import MAX_ACCURACY_METERS, distance_meters

LOCAL_TZ = ZoneInfo("Asia/Dushanbe")
DEVIATION_CONFIRMATIONS = 2
DEVIATION_COOLDOWN = timedelta(minutes=15)
LATE_WINDOW_MINUTES = 180


def weekdays(route) -> list[int]:
    """Рӯзҳои дурусти 1..7-ро аз model мехонад."""
    try:
        values = json.loads(route.weekdays_json or "[]")
    except (TypeError, ValueError):
        values = []
    return sorted({int(day) for day in values if isinstance(day, int) and 1 <= day <= 7})


def route_payload(route, places_by_id: dict) -> dict:
    """Масирро ба JSON-и мобилӣ табдил медиҳад."""
    start = places_by_id.get(route.start_place_id)
    end = places_by_id.get(route.end_place_id)
    if start is None or end is None:
        return {}
    return {
        "id": route.id,
        "name": route.name,
        "start_place_id": start.id,
        "end_place_id": end.id,
        "start_place": {"id": start.id, "name": start.name, "latitude": start.latitude, "longitude": start.longitude},
        "end_place": {"id": end.id, "name": end.name, "latitude": end.latitude, "longitude": end.longitude},
        "start_time": route.start_time,
        "arrive_by": route.arrive_by,
        "weekdays": weekdays(route),
        "corridor_meters": route.corridor_meters,
        "enabled": bool(route.enabled),
        "today_status": today_status(route),
    }


def today_status(route, now: datetime | None = None) -> str:
    """Ҳолати имрӯзаро бе сохтани маълумоти нав бармегардонад."""
    day = _local(now).date().isoformat()
    if route.arrival_date == day:
        return "arrived"
    if route.checkin_status and route.late_date == day:
        return route.checkin_status
    if route.deviation_active and route.trip_date == day:
        return "deviation"
    if route.trip_date == day:
        return "active"
    if route.late_date == day:
        return "late"
    return "idle"


def distance_to_segment_meters(lat: float, lng: float, start, end) -> float:
    """Масофаи нуқта то пораи масир бо projection-и маҳаллӣ."""
    mean_lat = math.radians((start.latitude + end.latitude + lat) / 3)
    scale_x = 111_320.0 * max(0.1, math.cos(mean_lat))
    scale_y = 111_195.0
    ax, ay = start.longitude * scale_x, start.latitude * scale_y
    bx, by = end.longitude * scale_x, end.latitude * scale_y
    px, py = lng * scale_x, lat * scale_y
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def on_location(db, child, routes, places, lat: float, lng: float, accuracy, now: datetime | None = None) -> None:
    """Нуқтаи навро барои оғоз, расидан ва дуршавӣ месанҷад."""
    if accuracy is not None and accuracy > MAX_ACCURACY_METERS:
        return
    local_now = _local(now)
    day = local_now.date().isoformat()
    by_id = {place.id: place for place in places}
    for route in routes:
        start, end = by_id.get(route.start_place_id), by_id.get(route.end_place_id)
        if not route.enabled or start is None or end is None or not _scheduled(route, local_now):
            continue
        if route.trip_date != day:
            route.trip_date = None
            route.outside_count = 0
            route.deviation_active = 0
        distance_end = distance_meters(lat, lng, end.latitude, end.longitude)
        if distance_end <= end.radius_meters:
            if route.arrival_date != day:
                route.arrival_date = day
                route.trip_date = day
                route.outside_count = 0
                route.deviation_active = 0
                route.checkin_status = None
                family_events.emit(
                    db, child, "parent", "safe_route_arrive",
                    f"{child.name} ба «{end.name}» расид", f"Масири «{route.name}» ба охир расид.",
                    {"route_id": route.id, "route": route.name, "place": end.name},
                )
            continue
        if not _in_active_window(route, local_now) or route.arrival_date == day:
            continue
        distance_route = distance_to_segment_meters(lat, lng, start, end)
        near_start = distance_meters(lat, lng, start.latitude, start.longitude) <= start.radius_meters
        if route.trip_date != day:
            if not near_start and distance_route > route.corridor_meters:
                continue
            route.trip_date = day
        if distance_route > route.corridor_meters:
            route.outside_count = (route.outside_count or 0) + 1
            if route.outside_count >= DEVIATION_CONFIRMATIONS and not route.deviation_active and _cooldown_passed(route, now):
                route.deviation_active = 1
                route.last_deviation_at = _utc_naive(now)
                family_events.emit(
                    db, child, "parent", "safe_route_deviation",
                    f"{child.name} аз масири бехатар дур шуд",
                    f"Тақрибан {round(distance_route)} м аз «{route.name}». GPS бо ду нуқта тасдиқ кард.",
                    {"route_id": route.id, "route": route.name, "distance_meters": round(distance_route)},
                )
        else:
            route.outside_count = 0
            if route.deviation_active:
                route.deviation_active = 0
                family_events.emit(
                    db, child, "parent", "safe_route_back",
                    f"{child.name} ба масири бехатар баргашт", route.name,
                    {"route_id": route.id, "route": route.name},
                )


def check_overdue(db, child, routes, places, now: datetime | None = None) -> bool:
    """Пас аз вақти расидан як бор волид ва фарзандро огоҳ мекунад."""
    local_now = _local(now)
    day = local_now.date().isoformat()
    by_id = {place.id: place for place in places}
    changed = False
    for route in routes:
        end = by_id.get(route.end_place_id)
        if not route.enabled or end is None or local_now.isoweekday() not in weekdays(route):
            continue
        due = _minutes(route.arrive_by)
        current = local_now.hour * 60 + local_now.minute
        if current < due or current > due + LATE_WINDOW_MINUTES or route.arrival_date == day or route.late_date == day:
            continue
        route.late_date = day
        route.checkin_status = "pending"
        changed = True
        data = {"route_id": route.id, "route": route.name, "place": end.name}
        family_events.emit(
            db, child, "parent", "safe_route_late",
            f"{child.name} ҳанӯз ба «{end.name}» нарасидааст",
            "GPS, интернет ва ҳолати фарзандро санҷед.", data,
        )
        family_events.emit(
            db, child, "child", "safe_route_checkin", "Ҳама чиз хуб аст?",
            f"Вақти масири «{route.name}» гузашт. Лутфан ба волидайн ҷавоб диҳед.", data,
        )
    return changed


def _local(now: datetime | None) -> datetime:
    value = now or datetime.now(timezone.utc)
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(LOCAL_TZ)


def _utc_naive(now: datetime | None) -> datetime:
    value = now or datetime.now(timezone.utc)
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def _minutes(value: str) -> int:
    hour, minute = value.split(":", 1)
    return int(hour) * 60 + int(minute)


def _scheduled(route, now: datetime) -> bool:
    current = now.hour * 60 + now.minute
    return now.isoweekday() in weekdays(route) and _minutes(route.start_time) - 30 <= current <= _minutes(route.arrive_by) + LATE_WINDOW_MINUTES


def _in_active_window(route, now: datetime) -> bool:
    current = now.hour * 60 + now.minute
    return _minutes(route.start_time) <= current <= _minutes(route.arrive_by) + 60


def _cooldown_passed(route, now: datetime | None) -> bool:
    previous = route.last_deviation_at
    if previous is None:
        return True
    if previous.tzinfo is None:
        previous = previous.replace(tzinfo=timezone.utc)
    current = now or datetime.now(timezone.utc)
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    return current.astimezone(timezone.utc) - previous.astimezone(timezone.utc) >= DEVIATION_COOLDOWN
