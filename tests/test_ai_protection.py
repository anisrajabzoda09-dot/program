"""Focused checks for Protection Center and safe Gemini previews."""

import os as _os
import sys as _sys

_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

from starlette.requests import Request
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core import gemini_ai
from app.core.mobile_auth import issue_token
from app.core.security import rate_limiter
from app.db.base import Base
from app.models.app_rule import AppRule
from app.models.child import Child
from app.models.user import User
from app.routers.mobile import mobile_snapshot_v2
from app.routers.mobile_family import (
    AiInstruction,
    AiCategoriesApply,
    AiCategoryAction,
    ProtectionState,
    ai_weekly_summary,
    preview_ai_rules,
    preview_ai_categories,
    apply_ai_categories,
    report_protection,
)


engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)


def request(token: str, role: str, path: str) -> Request:
    headers = [
        (b"authorization", f"Bearer {token}".encode()),
        (b"x-nigoh-role", role.encode()),
    ]
    return Request({
        "type": "http",
        "method": "POST",
        "scheme": "http",
        "path": path,
        "raw_path": path.encode(),
        "query_string": b"",
        "headers": headers,
        "client": ("127.0.0.1", 1234),
        "server": ("test", 80),
    })


def main() -> None:
    db = Session()
    parent = User(email="ai-parent@test.tj", full_name="Parent", role="parent")
    child_user = User(email="ai-child@test.tj", full_name="Child", role="child")
    db.add_all([parent, child_user])
    db.commit()
    db.refresh(parent)
    db.refresh(child_user)
    child = Child(
        parent_id=parent.id,
        user_id=child_user.id,
        name="Test child",
        age=11,
        pairing_code="818181",
        is_paired=1,
    )
    db.add(child)
    db.commit()
    db.refresh(child)
    db.add_all([
        AppRule(child_id=child.id, package_name="com.game.fun", app_name="Fun Game", is_installed=1),
        AppRule(child_id=child.id, package_name="com.android.dialer", app_name="Phone", is_installed=1),
    ])
    db.commit()
    parent_token = issue_token(db, parent)
    child_token = issue_token(db, child_user)
    child_id = child.id
    parent_request = request(parent_token, "parent", f"/api/mobile/v2/children/{child_id}/ai")
    child_request = request(child_token, "child", f"/api/mobile/v2/children/{child_id}/protection")

    result = report_protection(
        child_id,
        ProtectionState(
            usage=True,
            overlay=False,
            accessibility=True,
            location=True,
            notifications=True,
            appVersion="2.23.0",
            versionCode=51,
        ),
        child_request,
        db,
    )
    assert result["protection"]["overlay"] is False
    snapshot = mobile_snapshot_v2(parent_request, db)
    payload = snapshot["children"][0]
    assert payload["protection"]["appVersion"] == "2.23.0"

    original = gemini_ai.generate_json
    try:
        def fake_rules(prompt, schema):
            assert "Test child" not in prompt
            return {
                "summary": "Пешниҳод барои вақти бозӣ.",
                "actions": [
                    {"package_name": "com.game.fun", "daily_limit_minutes": 45, "reason": "Меъёр"},
                    {"package_name": "com.android.dialer", "is_blocked": True, "reason": "Нодуруст"},
                    {"package_name": "not.installed", "is_blocked": True, "reason": "Нодуруст"},
                ],
            }

        gemini_ai.generate_json = fake_rules
        response = preview_ai_rules(
            child_id,
            AiInstruction(instruction="Бозиро як соат мон"),
            parent_request,
            db,
        )
        proposal = response["proposal"]
        assert response["applied"] is False
        assert [item["package_name"] for item in proposal["actions"]] == [
            "com.game.fun", "com.android.dialer"
        ]
        assert proposal["actions"][1]["is_blocked"] is False
        assert db.query(AppRule).filter(AppRule.package_name == "com.game.fun").one().daily_limit_minutes == 60

        gemini_ai.generate_json = lambda prompt, schema: {
            "summary": "Истифода муътадил аст.", "tips": ["Танаффус кунед."]
        }
        response = ai_weekly_summary(child_id, parent_request, db)
        assert response["tips"] == ["Танаффус кунед."]

        gemini_ai.generate_json = lambda prompt, schema: {
            "categories": [
                {"package_name": "com.game.fun", "category": "games"},
                {"package_name": "not.installed", "category": "social"},
            ]
        }
        response = preview_ai_categories(child_id, parent_request, db)
        assert response == {
            "status": "success",
            "categories": [{"package_name": "com.game.fun", "category": "games"}],
            "applied": False,
        }
        assert db.query(AppRule).filter(AppRule.package_name == "com.game.fun").one().category is None
        response = apply_ai_categories(
            child_id,
            AiCategoriesApply(categories=[
                AiCategoryAction(package_name="com.game.fun", category="games")
            ]),
            parent_request,
            db,
        )
        assert response["updated"] == 1
        assert db.query(AppRule).filter(AppRule.package_name == "com.game.fun").one().category == "games"
    finally:
        gemini_ai.generate_json = original
        rate_limiter._history.clear()
        db.close()
    print("ALL AI/PROTECTION CHECKS PASSED")


if __name__ == "__main__":
    main()
