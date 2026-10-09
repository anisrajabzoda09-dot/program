"""Regression tests for installed-app snapshots and preserved parental rules."""

from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import app.main as main
from app.db.base import Base
from app.db.session import get_db
from app.models.app_rule import AppRule


class InstalledAppSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.session_factory = sessionmaker(bind=self.engine)

        def override_db():
            with self.session_factory() as session:
                yield session

        main.app.dependency_overrides[get_db] = override_db
        self.background_db = patch.object(main, "SessionLocal", self.session_factory)
        self.background_db.start()
        self.client = TestClient(main.app)

        parent = self.client.post(
            "/api/mobile/v3/auth/register",
            json={
                "email": "apps-parent@example.com",
                "password": "parentpass1",
                "full_name": "Parent",
            },
        ).json()
        child = self.client.post(
            "/api/mobile/v3/auth/register",
            json={
                "email": "apps-child@example.com",
                "password": "childpass1",
                "full_name": "Child",
            },
        ).json()
        self.parent_headers = {
            "Authorization": f"Bearer {parent['token']}",
            "X-NIGOH-Role": "parent",
        }
        self.child_headers = {
            "Authorization": f"Bearer {child['token']}",
            "X-NIGOH-Role": "child",
        }
        pair_code = self.client.post(
            "/api/mobile/v2/pair/code",
            json={"child_name": "Child", "gender": "boy", "age": 12},
            headers=self.child_headers,
        ).json()
        self.child_id = pair_code["child_id"]
        response = self.client.post(
            "/api/mobile/v2/pair",
            json={"pairing_code": pair_code["pairing_code"]},
            headers=self.parent_headers,
        )
        self.assertEqual(response.status_code, 200)

    def tearDown(self):
        self.client.close()
        self.background_db.stop()
        main.app.dependency_overrides.pop(get_db, None)
        self.engine.dispose()

    def sync(self, apps, *, complete=True):
        return self.client.post(
            f"/api/mobile/v2/children/{self.child_id}/apps/sync",
            json={"apps": apps, "snapshot_complete": complete},
            headers=self.child_headers,
        )

    def parent_apps(self):
        children = self.client.get(
            "/api/mobile/v2/snapshot",
            headers=self.parent_headers,
        ).json()["children"]
        return next(child for child in children if child["id"] == self.child_id)["apps"]

    def test_uninstalled_app_is_hidden_but_rule_survives_reinstall(self):
        initial = [
            {"package_name": "com.example.keep", "app_name": "Keep"},
            {"package_name": "com.example.remove", "app_name": "Remove"},
        ]
        self.assertEqual(self.sync(initial).status_code, 200)
        response = self.client.put(
            f"/api/mobile/v2/children/{self.child_id}/apps/com.example.remove",
            json={"daily_limit_minutes": 75},
            headers=self.parent_headers,
        )
        self.assertEqual(response.status_code, 200)

        self.assertEqual(self.sync(initial[:1]).status_code, 200)
        self.assertEqual(
            [app["package_name"] for app in self.parent_apps()],
            ["com.example.keep"],
        )
        with self.session_factory() as session:
            hidden = session.query(AppRule).filter_by(
                child_id=self.child_id,
                package_name="com.example.remove",
            ).one()
            self.assertEqual(hidden.is_installed, 0)
            self.assertEqual(hidden.daily_limit_minutes, 75)

        self.assertEqual(self.sync(initial).status_code, 200)
        apps = {app["package_name"]: app for app in self.parent_apps()}
        self.assertEqual(apps["com.example.remove"]["daily_limit_minutes"], 75)
        self.assertTrue(apps["com.example.remove"]["is_installed"])

    def test_empty_or_incomplete_snapshot_never_erases_apps(self):
        app = {"package_name": "com.example.safe", "app_name": "Safe"}
        self.assertEqual(self.sync([app]).status_code, 200)
        self.assertEqual(self.sync([], complete=True).status_code, 200)
        self.assertEqual(len(self.parent_apps()), 1)
        self.assertEqual(self.sync([], complete=False).status_code, 200)
        self.assertEqual(len(self.parent_apps()), 1)


if __name__ == "__main__":
    unittest.main()
