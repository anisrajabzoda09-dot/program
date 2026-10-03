"""Create, checksum, and retrieve versioned mobile configuration bundles."""

import hashlib
import json
from copy import deepcopy
from typing import Any

from sqlalchemy.orm import Session

from app.models.app_bundle import AppBundle


def canonical_json(value: Any) -> str:
    """Serialize a value deterministically for stable bundle checksums."""

    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def payload_checksum(payload: dict) -> str:
    """Return the SHA-256 checksum of a canonical bundle payload."""

    return hashlib.sha256(canonical_json(payload).encode("utf-8")).hexdigest()


def default_bundle_payload() -> dict:
    """Build the initial UI and parental-rule configuration for mobile apps."""

    return {
        "ui_overrides": {
            "theme": {
                "primaryColor": "#0095F6",
                "secondaryColor": "#070D18",
                "backgroundColor": "#FFFFFF",
                "surfaceColor": "#FFFFFF",
                "accentColor": "#00A98F",
            },
            "strings": {
                "app_name": "NIGOH Family",
                "home_title": "NIGOH Family",
                "parent_home_title": "NIGOH Apps",
                "update_banner": "Муҳофизати оила фаъол аст",
            },
            "visibility": {
                "demoLogin": False,
                "homeworkMode": True,
            },
        },
        "cached_rules_template": {
            "defaultDailyLimitMinutes": 90,
            "homeworkStart": "16:00",
            "homeworkEnd": "18:00",
            "homeworkWeekdays": [1, 2, 3, 4, 5],
        },
    }


def ensure_initial_bundle(db: Session) -> AppBundle:
    """Return the newest bundle, creating the default first version if absent."""

    bundle = db.query(AppBundle).order_by(AppBundle.bundle_version.desc()).first()
    if bundle:
        return bundle
    payload = default_bundle_payload()
    bundle = AppBundle(
        bundle_version=1,
        min_native_code=24,
        patch_type="config",
        payload=payload,
        checksum=payload_checksum(payload),
    )
    db.add(bundle)
    db.commit()
    db.refresh(bundle)
    return bundle


def list_after(db: Session, version: int) -> list[AppBundle]:
    """Return configuration patches newer than a client's installed version."""

    return (
        db.query(AppBundle)
        .filter(AppBundle.bundle_version > version)
        .order_by(AppBundle.bundle_version.asc())
        .all()
    )


def create_bundle(
    db: Session,
    *,
    min_native_code: int,
    patch_type: str,
    payload: dict,
) -> AppBundle:
    """Persist a new sequential configuration bundle and return it."""

    latest = db.query(AppBundle).order_by(AppBundle.bundle_version.desc()).first()
    next_version = (latest.bundle_version if latest else 0) + 1
    bundle = AppBundle(
        bundle_version=next_version,
        min_native_code=min_native_code,
        patch_type=patch_type,
        payload=deepcopy(payload),
        checksum=payload_checksum(payload),
    )
    db.add(bundle)
    db.commit()
    db.refresh(bundle)
    return bundle
