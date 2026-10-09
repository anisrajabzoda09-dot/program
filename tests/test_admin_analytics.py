"""Isolated regression checks for dashboard reporting and genuine APK downloads."""

import csv
from datetime import datetime, timedelta, timezone
from io import StringIO
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.main as main
import app.routers.admin as admin_router
from app.core.config import settings
from app.crud.crud_analytics import get_admin_dashboard_data
from app.db.base import Base
from app.db.session import get_db
from app.models.analytics import SiteAnalytics
from app.models.app_rule import AppRule
from app.models.child import Child
from app.models.contact import ContactMessage
from app.models.mobile_session import MobileSession
from app.models.user import User
from app.routers.download import get_android_release


class AdminAnalyticsTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
        Base.metadata.create_all(self.engine)
        self.session_factory = sessionmaker(bind=self.engine)
        self.db = self.session_factory()

        def override_db():
            with self.session_factory() as session:
                yield session

        main.app.dependency_overrides[get_db] = override_db
        self.background_db = patch.object(main, "SessionLocal", self.session_factory)
        self.background_db.start()
        self.client = TestClient(main.app)
        self.now = datetime(2026, 10, 8, 1, tzinfo=timezone.utc)

    def tearDown(self):
        self.client.close()
        self.background_db.stop()
        main.app.dependency_overrides.pop(get_db, None)
        self.db.close()
        self.engine.dispose()

    def event(self, when, kind="page_view", ip="192.0.2.1", version="v2.21.0"):
        self.db.add(SiteAnalytics(
            created_at=when, event_type=kind, ip=ip, path="/features",
            version=version, user_agent="Android",
        ))

    def test_empty_database_reports_zero_without_seeded_values(self):
        stats = get_admin_dashboard_data(self.db, now=self.now)
        self.assertEqual(len(stats["daily_chart"]), 30)
        self.assertEqual(set(stats["period_totals"].values()), {0})
        self.assertEqual(set(stats["changes"].values()), {0.0})
        self.assertEqual(stats["children_list"], [])
        self.assertEqual(stats["top_apps"], [])
        self.assertEqual(stats["download_versions"], [])
        self.assertEqual(stats["generated_at"], "2026-10-08T01:00:00+00:00")
        self.assertFalse(self.db.new or self.db.dirty or self.db.deleted)

    def test_timezone_boundaries_distinct_visitors_and_previous_period(self):
        self.event(datetime(2026, 10, 1, 18, 59, 59))
        self.event(datetime(2026, 10, 1, 19))
        self.event(datetime(2026, 10, 7, 18, 59, 59))
        self.event(datetime(2026, 10, 7, 19), ip="192.0.2.2")
        self.event(datetime(2026, 10, 8, 0), ip="192.0.2.2")
        self.event(datetime(2026, 10, 8, 0), ip=None)
        self.event(datetime(2026, 10, 8, 0), "qr_scan", "192.0.2.3", "v2.20.0")
        self.event(datetime(2026, 10, 8, 0), "apk_download", "192.0.2.4")
        self.event(datetime(2026, 10, 8, 0), "auth", "192.0.2.5")
        self.db.add(SiteAnalytics(created_at=datetime(2026, 10, 8, 0), event_type="page_view", ip="192.0.2.9", path="/admin"))
        self.db.add(SiteAnalytics(created_at=datetime(2026, 10, 8, 0), event_type="page_view", ip="192.0.2.10", path="/auth"))
        self.event(datetime(2026, 10, 8, 2), ip="192.0.2.6")
        self.db.add_all([
            User(email="parent@example.com", full_name="Parent", role="parent", created_at=datetime(2026, 10, 8, 0)),
            User(email="child@example.com", full_name="Child", role="child", created_at=datetime(2026, 10, 1, 18)),
            User(email="admin@example.com", full_name="Admin", role="admin", created_at=datetime(2026, 10, 8, 0)),
        ])
        self.db.commit()
        stats = get_admin_dashboard_data(self.db, days=7, now=self.now)
        self.assertEqual(stats["period"]["start_date"], "2026-10-02")
        self.assertEqual(stats["period"]["previous_start_date"], "2026-09-25")
        self.assertEqual(stats["period"]["timezone"], "Asia/Dushanbe")
        self.assertEqual(stats["period_totals"], {
            "page_views": 5, "visitors": 2, "downloads": 2,
            "direct_downloads": 1, "qr_downloads": 1, "registrations": 1,
        })
        self.assertEqual(stats["previous_period"]["page_views"], 1)
        self.assertEqual(stats["previous_period"]["registrations"], 1)
        self.assertEqual(stats["changes"]["page_views"], 400.0)
        self.assertIsNone(stats["changes"]["downloads"])
        self.assertEqual(stats["daily_chart"][0]["page_views"], 1)
        self.assertEqual(stats["daily_chart"][1]["page_views"], 0)
        self.assertEqual(stats["daily_chart"][-2]["page_views"], 1)
        self.assertEqual(stats["today_views"], 3)
        self.assertEqual(stats["today_downloads"], 2)
        self.assertEqual(sum(row["page_views"] for row in stats["daily_chart"]), 5)
        self.assertEqual(stats["total_page_views"], 6)
        self.assertEqual(stats["total_families"], 1)
        self.assertEqual(stats["total_users"], 2)
        self.assertEqual(stats["top_pages"], [{"path": "/features", "views": 5}])
        self.assertEqual(sum(row["downloads"] for row in stats["download_versions"]), 2)

    def test_presence_requires_observed_recent_activity(self):
        current = self.now.replace(tzinfo=None)
        accounts = [User(email=f"child{index}@example.com", full_name="Child", role="child") for index in range(4)]
        self.db.add_all(accounts)
        self.db.flush()
        children = [Child(name=f"Child {index}", pairing_code=f"code{index}", user_id=account.id) for index, account in enumerate(accounts)]
        self.db.add_all(children)
        self.db.flush()
        self.db.add_all([
            MobileSession(user_id=accounts[1].id, token_hash="active", created_at=current - timedelta(days=1), last_seen_at=current - timedelta(minutes=3)),
            MobileSession(user_id=accounts[2].id, token_hash="expired", created_at=current - timedelta(days=181), last_seen_at=current),
            AppRule(child_id=children[3].id, package_name="real.app", app_name="Real App", last_synced_at=current - timedelta(minutes=4)),
            AppRule(child_id=children[0].id, package_name="seed.app", app_name="Seed App"),
        ])
        children[0].location_updated_at = current + timedelta(minutes=10)
        self.db.commit()
        stats = get_admin_dashboard_data(self.db, now=self.now)
        by_id = {child["id"]: child for child in stats["children_list"]}
        self.assertFalse(by_id[children[0].id]["is_online"])
        self.assertTrue(by_id[children[1].id]["is_online"])
        self.assertEqual(by_id[children[1].id]["last_seen_source"], "session")
        self.assertFalse(by_id[children[2].id]["is_online"])
        self.assertTrue(by_id[children[3].id]["is_online"])
        self.assertEqual(by_id[children[3].id]["last_seen_source"], "apps")
        self.assertEqual(stats["total_online"], 2)
        self.assertEqual([app["package_name"] for app in stats["top_apps"]], ["real.app"])

    def test_admin_authorization_validation_and_aggregate_csv(self):
        for user in (None, {"role": "parent"}):
            with patch.object(admin_router, "get_current_user", return_value=user):
                for route in ("/api/admin/stats", "/api/admin/dashboard", "/api/admin/stats/export"):
                    self.assertEqual(self.client.get(route).status_code, 403)
                self.assertEqual(self.client.get("/admin", follow_redirects=False).status_code, 303)
        with patch.object(admin_router, "get_current_user", return_value={"role": "admin", "email": "admin@example.com"}):
            for days in ("0", "8", "-1", "900", "text", "7.5"):
                for route in ("/admin", "/api/admin/stats", "/api/admin/dashboard", "/api/admin/stats/export"):
                    self.assertEqual(self.client.get(f"{route}?days={days}").status_code, 422)
            for days in (7, 14, 30, 90):
                response = self.client.get(f"/api/admin/stats?days={days}")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(len(response.json()["daily_chart"]), days)
                self.assertEqual(response.headers["cache-control"], "no-store")
            response = self.client.get("/api/admin/stats/export?days=7")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.headers["cache-control"], "no-store")
            self.assertIn('attachment; filename="nigoh-statistics-', response.headers["content-disposition"])
            records = list(csv.DictReader(StringIO(response.content.decode("utf-8-sig"))))
            self.assertEqual(len(records), 7)
            self.assertEqual(records[0]["timezone"], "Asia/Dushanbe")
            self.assertEqual(set(records[0]), {"date", "timezone", "page_views", "visitors", "downloads", "direct_downloads", "qr_downloads", "registrations"})

    def test_fragment_read_only_and_page_marks_only_displayed_messages(self):
        self.db.add_all([ContactMessage(name="Parent", email="parent@example.com", message=f"Message {index}") for index in range(51)])
        self.db.commit()
        with patch.object(admin_router, "get_current_user", return_value={"role": "admin", "email": "admin@example.com"}):
            response = self.client.get("/api/admin/dashboard?days=14")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.headers["cache-control"], "no-store")
            self.assertEqual(self.db.query(ContactMessage).filter(ContactMessage.is_read == 0).count(), 51)
            self.assertEqual(self.db.query(SiteAnalytics).count(), 0)
            response = self.client.get("/admin?days=7")
            self.assertEqual(response.status_code, 200)
            self.db.expire_all()
            unread = self.db.query(ContactMessage).filter(ContactMessage.is_read == 0).all()
            self.assertEqual(len(unread), 1)
            self.assertEqual(unread[0].message, "Message 0")

    def test_child_profile_validation_and_trimmed_updates(self):
        child = Child(name="Original", pairing_code="profilecode", age=10)
        self.db.add(child)
        self.db.commit()
        with patch.object(admin_router, "get_current_user", return_value={"role": "admin"}):
            for fields in ({"age": -1}, {"age": 26}, {"name": "   "}, {"name": "a" * 81}, {"device_name": "a" * 81}, {"gender": "other"}, {"child_id": 0}):
                response = self.client.post("/api/admin/child/update", json={"child_id": child.id, **fields})
                self.assertEqual(response.status_code, 422)
            response = self.client.post("/api/admin/child/update", json={"child_id": child.id, "name": "  Али  ", "age": None})
            self.assertEqual(response.status_code, 200)
            self.db.refresh(child)
            self.assertEqual(child.name, "Али")
            self.assertEqual(child.age, 10)

    def test_only_real_apk_get_requests_count_and_fallback_version_matches(self):
        with TemporaryDirectory() as directory:
            downloads = Path(directory) / "downloads"
            downloads.mkdir()
            candidates = ["NIGOH_Family_Android_v2.21.0.apk", "NIGOH_Family_Android_v2.20.0.apk"]
            with patch.object(settings, "STATIC_DIR", directory), patch.object(settings, "BASE_DIR", directory), patch.object(settings, "APK_CANDIDATES", candidates):
                missing = self.client.get("/download/android")
                self.assertEqual(missing.status_code, 503)
                self.assertNotIn("content-disposition", missing.headers)
                self.assertEqual(self.db.query(SiteAnalytics).count(), 0)
                (downloads / candidates[0]).write_bytes(b"not an APK" * 110_000)
                self.assertFalse(get_android_release()["available"])
                with ZipFile(downloads / candidates[1], "w") as archive:
                    archive.writestr("AndroidManifest.xml", b"manifest")
                    archive.writestr("classes.dex", b"dex" * 400_000)
                release = get_android_release()
                self.assertTrue(release["available"])
                self.assertEqual(release["version"], "2.20.0")
                self.assertIsNone(release["version_code"])
                self.assertEqual(self.client.head("/download/android").status_code, 200)
                self.assertEqual(self.db.query(SiteAnalytics).count(), 0)
                response = self.client.get("/download/android")
                self.assertEqual(response.status_code, 200)
                self.assertTrue(response.content.startswith(b"PK"))
                self.assertEqual(self.client.get("/qr").status_code, 200)
                self.assertEqual([(row.event_type, row.version) for row in self.db.query(SiteAnalytics).order_by(SiteAnalytics.id)], [("apk_download", "v2.20.0"), ("qr_scan", "v2.20.0")])


if __name__ == "__main__":
    unittest.main()
