"""Файл: амалиёти пойгоҳи додаҳо барои бахши `crud_analytics`."""

from datetime import date, datetime, time, timedelta, timezone
from typing import Optional
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session
from sqlalchemy import and_, case, func, distinct
from app.models.analytics import SiteAnalytics
from app.models.user import User
from app.models.child import Child
from app.models.app_rule import AppRule
from app.models.app_usage import AppUsageDaily
from app.models.mobile_session import MobileSession
from app.core.config import settings
from app.core.mobile_auth import SESSION_TTL

def log_analytics_event(
    db: Session,
    ip: str,
    path: str,
    user_agent: str,
    event_type: str = "page_view",
    version: str = "v2.8.1"
):
    """log омор event-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    try:
        event = SiteAnalytics(
            ip=ip or "127.0.0.1",
            path=path,
            user_agent=(user_agent or "")[:250],
            event_type=event_type,
            version=version
        )
        db.add(event)
        db.commit()
    except Exception:
        db.rollback()

_DOWNLOAD_EVENTS = ["apk_download", "qr_scan"]
_SEEDED_DEVICE_NAMES = {"Samsung Galaxy A54", ""}
_DAY_NAMES = ["Дш", "Сш", "Чш", "Пш", "Ҷм", "Шб", "Яш"]
_REPORTING_TIMEZONE = ZoneInfo("Asia/Dushanbe")
_ALLOWED_DAYS = (7, 14, 30, 90)
_INTERNAL_PAGE_PATHS = ("/admin", "/auth")


def _utc_naive(moment: datetime) -> datetime:
    if moment.tzinfo is not None:
        moment = moment.astimezone(timezone.utc).replace(tzinfo=None)
    return moment


def _iso_utc(moment: Optional[datetime]) -> Optional[str]:
    return _utc_naive(moment).replace(tzinfo=timezone.utc).isoformat() if moment else None


def _event_columns() -> tuple:
    public_view = and_(
        SiteAnalytics.event_type == "page_view",
        SiteAnalytics.path.notin_(_INTERNAL_PAGE_PATHS),
    )
    return (
        func.sum(case((public_view, 1), else_=0)),
        func.count(distinct(case(
            (public_view, func.nullif(SiteAnalytics.ip, "")),
            else_=None,
        ))),
        func.sum(case((SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS), 1), else_=0)),
        func.sum(case((SiteAnalytics.event_type == "apk_download", 1), else_=0)),
        func.sum(case((SiteAnalytics.event_type == "qr_scan", 1), else_=0)),
    )


def _event_totals(db: Session, start: Optional[datetime], end: datetime) -> dict:
    query = db.query(*_event_columns()).filter(SiteAnalytics.created_at <= end)
    if start is not None:
        query = query.filter(SiteAnalytics.created_at >= start)
    values = query.one()
    return dict(zip(
        ("page_views", "visitors", "downloads", "direct_downloads", "qr_downloads"),
        (int(value or 0) for value in values),
    ))


def _daily_series(db: Session, start: datetime, end: datetime, days: int) -> list:
    since = start.replace(tzinfo=timezone.utc).astimezone(_REPORTING_TIMEZONE).date()
    day = func.date(SiteAnalytics.created_at, "+5 hours")
    rows = db.query(day, *_event_columns()).filter(
        SiteAnalytics.created_at >= start, SiteAnalytics.created_at <= end,
    ).group_by(day).all()
    by_day = {str(row[0]): tuple(int(value or 0) for value in row[1:]) for row in rows}
    registered_day = func.date(User.created_at, "+5 hours")
    registrations = dict(db.query(registered_day, func.count(User.id)).filter(
        User.role != "admin", User.created_at >= start, User.created_at <= end,
    ).group_by(registered_day).all())
    series = []
    for offset in range(days):
        current = since + timedelta(days=offset)
        views, visitors, downloads, direct, qr = by_day.get(current.isoformat(), (0, 0, 0, 0, 0))
        series.append({
            "date": current.isoformat(),
            "label": f"{current.day:02d}.{current.month:02d}",
            "weekday": _DAY_NAMES[current.weekday()],
            "page_views": views,
            "downloads": downloads,
            "visitors": visitors,
            "direct_downloads": direct,
            "qr_downloads": qr,
            "registrations": int(registrations.get(current.isoformat(), 0)),
        })
    return series


def _top_apps(db: Session, today: date, limit: int = 8) -> list:
    """Маълумоти ёрирасони top app-ҳо-ро омода карда, ба caller бармегардонад."""
    rows = db.query(
        AppRule.package_name,
        func.max(AppRule.app_name),
        func.count(distinct(AppRule.child_id)),
        func.sum(case((AppRule.is_blocked == 1, 1), else_=0)),
        func.sum(case((AppRule.daily_limit_minutes > 0, 1), else_=0)),
    ).filter(AppRule.last_synced_at.isnot(None)).group_by(AppRule.package_name).order_by(
        func.count(distinct(AppRule.child_id)).desc(), func.max(AppRule.app_name)
    ).limit(limit).all()
    usage = dict(db.query(AppUsageDaily.package_name, func.sum(AppUsageDaily.minutes)).filter(
        AppUsageDaily.usage_date == today
    ).group_by(AppUsageDaily.package_name).all())
    return [{
        "package_name": r[0],
        "app_name": r[1] or r[0],
        "children": int(r[2] or 0),
        "blocked": int(r[3] or 0),
        "limited": int(r[4] or 0),
        "minutes_today": int(usage.get(r[0]) or 0),
    } for r in rows]


def get_admin_dashboard_data(db: Session, days: int = 30, now: Optional[datetime] = None) -> dict:
    """Омори воқеии сайт ва оиларо барои dashboard-и admin ҳисоб мекунад."""
    if days not in _ALLOWED_DAYS:
        raise ValueError("days must be one of 7, 14, 30, 90")
    current_time = _utc_naive(now or datetime.now(timezone.utc))
    today = current_time.replace(tzinfo=timezone.utc).astimezone(_REPORTING_TIMEZONE).date()
    first_day = today - timedelta(days=days - 1)
    start = _utc_naive(datetime.combine(first_day, time.min, tzinfo=_REPORTING_TIMEZONE))
    previous_start = start - timedelta(days=days)
    previous_end = start - timedelta(microseconds=1)
    totals = _event_totals(db, None, current_time)
    period_totals = _event_totals(db, start, current_time)
    previous_period = _event_totals(db, previous_start, previous_end)
    for values, lower, upper in (
        (period_totals, start, current_time),
        (previous_period, previous_start, previous_end),
    ):
        values["registrations"] = db.query(User).filter(
            User.role != "admin", User.created_at >= lower, User.created_at <= upper,
        ).count()
    changes = {
        key: round((value - previous_period[key]) / previous_period[key] * 100, 1)
        if previous_period[key] else (0.0 if value == 0 else None)
        for key, value in period_totals.items()
    }
    daily_chart = _daily_series(db, start, current_time, days)
    android_downloads = db.query(SiteAnalytics).filter(
        SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS),
        SiteAnalytics.user_agent.ilike("%android%"),
        SiteAnalytics.created_at <= current_time,
    ).count()

    users = db.query(User).filter(User.role != "admin").order_by(User.id.desc()).all()
    role_counts = {"parent": 0, "child": 0, "unassigned": 0}
    for user in users:
        role_counts[user.role if user.role in role_counts else "unassigned"] += 1
    users_by_id = {user.id: user for user in users}

    children = db.query(Child).order_by(Child.id.desc()).all()
    synced_children = dict(db.query(AppRule.child_id, func.max(AppRule.last_synced_at)).filter(
        AppRule.last_synced_at.isnot(None), AppRule.last_synced_at <= current_time,
    ).group_by(AppRule.child_id).all())
    session_activity = dict(db.query(MobileSession.user_id, func.max(MobileSession.last_seen_at)).filter(
        MobileSession.created_at >= current_time - SESSION_TTL,
        MobileSession.created_at <= current_time,
        MobileSession.last_seen_at <= current_time,
    ).group_by(MobileSession.user_id).all())
    children_list = []
    online = 0
    for child in children:
        activity = [
            (_utc_naive(moment), source)
            for moment, source in (
                (child.location_updated_at, "location"),
                (synced_children.get(child.id), "apps"),
                (session_activity.get(child.user_id), "session"),
            )
            if moment is not None and _utc_naive(moment) <= current_time
        ]
        last_seen, last_seen_source = max(activity) if activity else (None, None)
        is_online = last_seen is not None and current_time - last_seen <= timedelta(minutes=15)
        online += is_online
        parent = users_by_id.get(child.parent_id)
        children_list.append({
            "id": child.id,
            "name": child.name,
            "gender": child.gender,
            "age": child.age,
            "device_name": None if not last_seen and (child.device_name or "") in _SEEDED_DEVICE_NAMES else (child.device_name or None),
            "is_paired": bool(child.is_paired),
            "is_online": is_online,
            "apps_synced": child.id in synced_children,
            "parent_email": parent.email if parent else None,
            "location_updated_at": _iso_utc(child.location_updated_at),
            "last_seen_at": _iso_utc(last_seen),
            "last_seen_source": last_seen_source,
            "created_at": _iso_utc(child.created_at),
        })

    top_pages = [{"path": row[0], "views": int(row[1])} for row in db.query(
        SiteAnalytics.path, func.count(SiteAnalytics.id)
    ).filter(
        SiteAnalytics.event_type == "page_view",
        SiteAnalytics.path.notin_(_INTERNAL_PAGE_PATHS),
        SiteAnalytics.created_at >= start,
        SiteAnalytics.created_at <= current_time,
    ).group_by(SiteAnalytics.path).order_by(
        func.count(SiteAnalytics.id).desc(), SiteAnalytics.path,
    ).limit(6).all()]

    download_query = db.query(SiteAnalytics).filter(
        SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS), SiteAnalytics.created_at <= current_time,
    )
    downloads = download_query.order_by(SiteAnalytics.created_at.desc(), SiteAnalytics.id.desc()).limit(10).all()
    version = func.coalesce(func.nullif(SiteAnalytics.version, ""), "unknown")
    download_versions = [{"version": row[0], "downloads": int(row[1])} for row in db.query(
        version, func.count(SiteAnalytics.id),
    ).filter(
        SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS), SiteAnalytics.created_at >= start,
        SiteAnalytics.created_at <= current_time,
    ).group_by(version).order_by(func.count(SiteAnalytics.id).desc(), version).all()]
    registered_users = []
    for user in users:
        account = user.to_dict()
        account["created_at"] = _iso_utc(user.created_at)
        account["auth_providers"] = [
            provider for provider, identifier in (
                ("Google", user.google_id), ("GitHub", user.github_id),
                ("Apple", user.apple_id), ("Firebase", user.firebase_uid),
                ("Email", user.password_hash),
            ) if identifier
        ]
        registered_users.append(account)

    return {
        "current_version": f"v{settings.APP_VERSION}",
        "generated_at": _iso_utc(current_time),
        "period": {
            "days": days, "start_date": first_day.isoformat(), "end_date": today.isoformat(),
            "previous_start_date": (first_day - timedelta(days=days)).isoformat(),
            "previous_end_date": (first_day - timedelta(days=1)).isoformat(),
            "timezone": _REPORTING_TIMEZONE.key, "includes_today": True,
        },
        "period_totals": period_totals,
        "previous_period": previous_period,
        "changes": changes,
        "download_sources": [
            {"source": "direct", "downloads": period_totals["direct_downloads"]},
            {"source": "qr", "downloads": period_totals["qr_downloads"]},
        ],
        "download_versions": download_versions,
        "total_downloads": totals["downloads"],
        "total_qr_downloads": totals["qr_downloads"],
        "total_direct_downloads": totals["direct_downloads"],
        "android_downloads": android_downloads,
        "total_page_views": totals["page_views"],
        "total_visitors": totals["visitors"],
        "today_views": daily_chart[-1]["page_views"],
        "today_downloads": daily_chart[-1]["downloads"],
        "total_users": len(users),
        "total_families": role_counts["parent"],
        "role_counts": role_counts,
        "total_children": len(children),
        "total_paired": sum(1 for child in children if child.is_paired),
        "total_online": online,
        "children_with_apps": len(synced_children),
        "blocked_rules": db.query(AppRule).filter(AppRule.is_blocked == 1, AppRule.last_synced_at.isnot(None)).count(),
        "daily_chart": daily_chart,
        "top_apps": _top_apps(db, today),
        "top_pages": top_pages,
        "children_list": children_list,
        "recent_downloads": [dict(download.to_dict(), created_at=_iso_utc(download.created_at)) for download in downloads],
        "registered_users": registered_users,
    }
