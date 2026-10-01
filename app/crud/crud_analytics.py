from datetime import date, datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy import case, func, distinct
from app.models.analytics import SiteAnalytics
from app.models.user import User
from app.models.child import Child
from app.models.app_rule import AppRule
from app.models.app_usage import AppUsageDaily
from app.core.config import settings

def log_analytics_event(
    db: Session,
    ip: str,
    path: str,
    user_agent: str,
    event_type: str = "page_view",
    version: str = "v2.8.1"
):
    """Log visit, APK download, or QR scan into site_analytics."""
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


def _is_recent(moment: Optional[datetime], minutes: int) -> bool:
    if moment is None:
        return False
    if moment.tzinfo is not None:
        moment = moment.astimezone(timezone.utc).replace(tzinfo=None)
    return datetime.utcnow() - moment <= timedelta(minutes=minutes)


def _daily_series(db: Session, days: int = 14) -> list:
    """Page views, downloads and unique visitors per day, oldest first."""
    since = date.today() - timedelta(days=days - 1)
    day = func.date(SiteAnalytics.created_at)
    rows = db.query(
        day.label("day"),
        func.sum(case((SiteAnalytics.event_type == "page_view", 1), else_=0)),
        func.sum(case((SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS), 1), else_=0)),
        func.count(distinct(SiteAnalytics.ip)),
    ).filter(day >= since.isoformat()).group_by(day).all()
    by_day = {str(r[0]): (int(r[1] or 0), int(r[2] or 0), int(r[3] or 0)) for r in rows}
    series = []
    for offset in range(days):
        current = since + timedelta(days=offset)
        views, downloads, visitors = by_day.get(current.isoformat(), (0, 0, 0))
        series.append({
            "date": current.isoformat(),
            "label": f"{current.day:02d}.{current.month:02d}",
            "weekday": _DAY_NAMES[current.weekday()],
            "page_views": views,
            "downloads": downloads,
            "visitors": visitors,
        })
    return series


def _top_apps(db: Session, limit: int = 8) -> list:
    """Apps really reported by children's phones, most common first."""
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
        AppUsageDaily.usage_date == date.today()
    ).group_by(AppUsageDaily.package_name).all())
    return [{
        "package_name": r[0],
        "app_name": r[1] or r[0],
        "children": int(r[2] or 0),
        "blocked": int(r[3] or 0),
        "limited": int(r[4] or 0),
        "minutes_today": int(usage.get(r[0]) or 0),
    } for r in rows]


def get_admin_dashboard_data(db: Session) -> dict:
    """Real site and family statistics for the admin panel — no sample values."""
    total_downloads = db.query(SiteAnalytics).filter(SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS)).count()
    total_qr_downloads = db.query(SiteAnalytics).filter(SiteAnalytics.event_type == "qr_scan").count()
    total_page_views = db.query(SiteAnalytics).filter(SiteAnalytics.event_type == "page_view").count()
    total_visitors = db.query(func.count(distinct(SiteAnalytics.ip))).scalar() or 0
    android_downloads = db.query(SiteAnalytics).filter(
        SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS),
        SiteAnalytics.user_agent.ilike("%android%"),
    ).count()

    users = db.query(User).filter(User.role != "admin").order_by(User.id.desc()).all()
    role_counts = {"parent": 0, "child": 0, "unassigned": 0}
    for u in users:
        role_counts[u.role if u.role in role_counts else "unassigned"] += 1
    users_by_id = {u.id: u for u in users}

    children = db.query(Child).order_by(Child.id.desc()).all()
    synced_children = {row[0] for row in db.query(AppRule.child_id).filter(AppRule.last_synced_at.isnot(None)).distinct().all()}
    children_list = []
    online = 0
    for c in children:
        is_online = _is_recent(c.location_updated_at, 15)
        online += is_online
        parent = users_by_id.get(c.parent_id)
        children_list.append({
            "id": c.id,
            "name": c.name,
            "gender": c.gender,
            "age": c.age,
            "device_name": None if (c.device_name or "") in _SEEDED_DEVICE_NAMES else c.device_name,
            "is_paired": bool(c.is_paired),
            "is_online": is_online,
            "apps_synced": c.id in synced_children,
            "parent_email": parent.email if parent else None,
            "location_updated_at": c.location_updated_at.isoformat() if c.location_updated_at else None,
            "created_at": str(c.created_at) if c.created_at else None,
        })

    today = date.today().isoformat()
    today_views = db.query(SiteAnalytics).filter(
        SiteAnalytics.event_type == "page_view", func.date(SiteAnalytics.created_at) == today
    ).count()
    today_downloads = db.query(SiteAnalytics).filter(
        SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS), func.date(SiteAnalytics.created_at) == today
    ).count()
    top_pages = [{"path": r[0], "views": int(r[1])} for r in db.query(
        SiteAnalytics.path, func.count(SiteAnalytics.id)
    ).filter(SiteAnalytics.event_type == "page_view").group_by(SiteAnalytics.path).order_by(
        func.count(SiteAnalytics.id).desc()
    ).limit(6).all()]

    downloads = db.query(SiteAnalytics).filter(SiteAnalytics.event_type.in_(_DOWNLOAD_EVENTS)).order_by(SiteAnalytics.id.desc()).limit(10).all()

    return {
        "current_version": f"v{settings.APP_VERSION}",
        "total_downloads": total_downloads,
        "total_qr_downloads": total_qr_downloads,
        "total_direct_downloads": max(0, total_downloads - total_qr_downloads),
        "android_downloads": android_downloads,
        "total_page_views": total_page_views,
        "total_visitors": total_visitors,
        "today_views": today_views,
        "today_downloads": today_downloads,
        "total_families": len(users),
        "role_counts": role_counts,
        "total_children": len(children),
        "total_paired": sum(1 for c in children if c.is_paired),
        "total_online": online,
        "children_with_apps": len(synced_children),
        "blocked_rules": db.query(AppRule).filter(AppRule.is_blocked == 1, AppRule.last_synced_at.isnot(None)).count(),
        "daily_chart": _daily_series(db),
        "top_apps": _top_apps(db),
        "top_pages": top_pages,
        "children_list": children_list,
        "recent_downloads": [d.to_dict() for d in downloads],
        "registered_users": [u.to_dict() for u in users],
    }
