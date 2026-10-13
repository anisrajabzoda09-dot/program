"""Санҷиши масири бехатар: API, дуршавӣ, расидан ва check-in."""

import os as _os
import sys as _sys

_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import uuid
from datetime import datetime
from types import SimpleNamespace

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core import safe_routes
from app.core.security import rate_limiter
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.family_extras import SafePlace, SafeRoute

PASSED = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global PASSED
    if not ok:
        raise AssertionError(f"FAIL {name} {detail}")
    PASSED += 1
    print(f"ok  {name}")


class FakeDb:
    def __init__(self):
        self.events = []

    def add(self, item):
        self.events.append(item)


def route_fixture():
    home = SimpleNamespace(id=1, name="Хона", latitude=38.55, longitude=68.75, radius_meters=150)
    school = SimpleNamespace(id=2, name="Мактаб", latitude=38.55, longitude=68.80, radius_meters=150)
    route = SimpleNamespace(
        id=7, child_id=1, start_place_id=1, end_place_id=2, name="Хона — мактаб",
        start_time="07:30", arrive_by="08:00", weekdays_json="[1,2,3,4,5]", corridor_meters=300,
        enabled=1, trip_date=None, arrival_date=None, late_date=None, checkin_status=None,
        outside_count=0, deviation_active=0, last_deviation_at=None,
    )
    return home, school, route


def unit_checks() -> None:
    home, school, route = route_fixture()
    child = SimpleNamespace(id=1, name="Али")
    db = FakeDb()
    monday = datetime.fromisoformat("2026-10-12T07:35:00+05:00")
    safe_routes.on_location(db, child, [route], [home, school], home.latitude, home.longitude, 10, monday)
    check("trip starts at real start place", route.trip_date == "2026-10-12")
    safe_routes.on_location(db, child, [route], [home, school], 38.56, 68.775, 10, monday)
    check("one outside point is not enough", not db.events and route.outside_count == 1)
    safe_routes.on_location(db, child, [route], [home, school], 38.56, 68.776, 10, monday)
    check("two outside points confirm deviation", [event.kind for event in db.events] == ["safe_route_deviation"])
    safe_routes.on_location(db, child, [route], [home, school], 38.55, 68.775, 10, monday)
    check("return to corridor notifies parent", [event.kind for event in db.events][-1] == "safe_route_back")
    safe_routes.on_location(db, child, [route], [home, school], school.latitude, school.longitude, 10, monday)
    check("arrival closes route", route.arrival_date == "2026-10-12" and db.events[-1].kind == "safe_route_arrive")

    home, school, late = route_fixture()
    late_db = FakeDb()
    safe_routes.check_overdue(late_db, child, [late], [home, school], datetime.fromisoformat("2026-10-12T08:05:00+05:00"))
    safe_routes.check_overdue(late_db, child, [late], [home, school], datetime.fromisoformat("2026-10-12T08:06:00+05:00"))
    check("late alert emitted once for both roles", [event.target_role for event in late_db.events] == ["parent", "child"])
    check("late route asks for check-in", late.checkin_status == "pending" and safe_routes.today_status(late, datetime.fromisoformat("2026-10-12T08:06:00+05:00")) == "pending")
    distance = safe_routes.distance_to_segment_meters(38.56, 68.775, home, school)
    check("distance to route is realistic", 1000 < distance < 1200, str(distance))


engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)


def override_db():
    db = Session()
    try:
        yield db
    finally:
        db.close()


def api_checks() -> None:
    app.dependency_overrides[get_db] = override_db
    rate_limiter._history.clear()
    client = TestClient(app)
    headers = lambda token, role: {"Authorization": f"Bearer {token}", "X-NIGOH-Role": role}
    suffix = uuid.uuid4().hex[:6]
    try:
        register = lambda email: client.post(
            "/api/mobile/v3/auth/register",
            json={"email": email, "password": "longpass12", "full_name": "Т"},
        ).json()["token"]
        parent_token = register(f"srp{suffix}@x.tj")
        child_token = register(f"src{suffix}@x.tj")
        code = client.post(
            "/api/mobile/v2/pair/code",
            json={"child_name": "Али", "gender": "boy", "age": 10},
            headers=headers(child_token, "child"),
        ).json()
        child_id = code["child_id"]
        client.post("/api/mobile/v2/pair", json={"pairing_code": code["pairing_code"]}, headers=headers(parent_token, "parent"))
        place_ids = []
        for name, longitude in (("Хона", 68.75), ("Мактаб", 68.80)):
            response = client.post(
                f"/api/mobile/v2/children/{child_id}/places",
                json={"name": name, "latitude": 38.55, "longitude": longitude, "radius_meters": 150},
                headers=headers(parent_token, "parent"),
            )
            place_ids.append(response.json()["place"]["id"])
        payload = {
            "name": "Хона — мактаб", "start_place_id": place_ids[0], "end_place_id": place_ids[1],
            "start_time": "07:30", "arrive_by": "08:00", "weekdays": [1, 2, 3, 4, 5], "corridor_meters": 300,
        }
        response = client.post(f"/api/mobile/v2/children/{child_id}/safe-routes", json=payload, headers=headers(parent_token, "parent"))
        check("parent creates route", response.status_code == 200, response.text)
        route = response.json()["route"]
        check("route contains real place names", route["start_place"]["name"] == "Хона" and route["end_place"]["name"] == "Мактаб")
        response = client.post(f"/api/mobile/v2/children/{child_id}/safe-routes", json=payload, headers=headers(child_token, "child"))
        check("child cannot create route", response.status_code == 403)
        response = client.put(
            f"/api/mobile/v2/children/{child_id}/safe-routes/{route['id']}",
            json={"enabled": False}, headers=headers(parent_token, "parent"),
        )
        check("parent can pause route", response.status_code == 200 and response.json()["route"]["enabled"] is False)
        snapshot = client.get("/api/mobile/v2/snapshot", headers=headers(child_token, "child")).json()["child"]
        check("child snapshot carries route", snapshot["safe_routes"][0]["id"] == route["id"])

        db = Session()
        row = db.query(SafeRoute).filter(SafeRoute.id == route["id"]).first()
        row.enabled = 1
        row.late_date = datetime.now(safe_routes.LOCAL_TZ).date().isoformat()
        row.checkin_status = "pending"
        db.commit()
        db.close()
        response = client.post(
            f"/api/mobile/v2/children/{child_id}/safe-routes/{route['id']}/checkin",
            json={"status": "ok"}, headers=headers(child_token, "child"),
        )
        check("child answers safety check", response.status_code == 200 and response.json()["checkin_status"] == "ok", response.text)
        response = client.delete(
            f"/api/mobile/v2/children/{child_id}/places/{place_ids[0]}", headers=headers(parent_token, "parent"),
        )
        remaining = client.get(f"/api/mobile/v2/children/{child_id}/safe-routes", headers=headers(parent_token, "parent")).json()["routes"]
        check("deleting endpoint removes broken route", response.status_code == 200 and remaining == [])
    finally:
        rate_limiter._history.clear()
        app.dependency_overrides.clear()


if __name__ == "__main__":
    unit_checks()
    api_checks()
    print(f"\nALL {PASSED} CHECKS PASSED")
