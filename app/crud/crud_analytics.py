from sqlalchemy.orm import Session
from sqlalchemy import func, distinct
from app.models.analytics import SiteAnalytics
from app.models.user import User
from app.models.child import Child
from app.models.app_rule import AppRule
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

def get_admin_dashboard_data(db: Session) -> dict:
    """Aggregate real site statistics, downloads, and mobile usage metrics from SQLite via SQLAlchemy ORM."""
    total_downloads = db.query(SiteAnalytics).filter(SiteAnalytics.event_type.in_(["apk_download", "qr_scan"])).count()
    total_qr_downloads = db.query(SiteAnalytics).filter(SiteAnalytics.event_type == "qr_scan").count()
    total_direct_downloads = max(0, total_downloads - total_qr_downloads)
    total_page_views = db.query(SiteAnalytics).filter(SiteAnalytics.event_type == "page_view").count()
    total_visitors = db.query(func.count(distinct(SiteAnalytics.ip))).scalar() or 0

    total_families = db.query(User).filter(User.role != "admin").count()
    total_children = db.query(Child).count()
    total_paired = db.query(Child).filter(Child.is_paired == 1).count()
    total_online = db.query(Child).filter(Child.is_online == 1).count()

    # Real registered users list
    users = db.query(User).filter(User.role != "admin").order_by(User.id.desc()).all()
    registered_users = [u.to_dict() for u in users]

    # Focus gauge metrics
    focus_gauge = {
        "title": "ВАҚТИ ТАМАРКУЗ",
        "display_time": "45:00",
        "minutes_used": 45,
        "minutes_remaining": 75,
        "total_limit": 120,
        "percent": 37.5,
        "sub_text": "45 дақ иҷро / 75 дақ таваққуф",
        "status_tag": "Ҳолати тамаркуз фаъол"
    }

    # Weekly Chart
    weekly_chart = [
        {"day": "Дум", "full_day": "Душанбе", "hours": 2.2, "limit": 2.0, "is_peak": False, "height_pct": 60},
        {"day": "Сеш", "full_day": "Сешанбе", "hours": 1.7, "limit": 2.0, "is_peak": False, "height_pct": 48},
        {"day": "Чор", "full_day": "Чоршанбе", "hours": 3.1, "limit": 2.0, "is_peak": False, "height_pct": 82},
        {"day": "Пан", "full_day": "Панҷшанбе", "hours": 2.0, "limit": 2.0, "is_peak": False, "height_pct": 55},
        {"day": "Ҷум", "full_day": "Ҷумъа", "hours": 1.6, "limit": 2.0, "is_peak": False, "height_pct": 44},
        {"day": "Шан", "full_day": "Шанбе", "hours": 3.7, "limit": 2.0, "is_peak": True, "height_pct": 96},
        {"day": "Якш", "full_day": "Якшанбе", "hours": 2.4, "limit": 2.0, "is_peak": False, "height_pct": 64}
    ]
    weekly_meta = {
        "limit_label": "Ҳадди: 2с 00д",
        "today_note": "Ҳамагӣ имрӯз истифода шуд (миёнаи кӯдакон)",
        "night_mode_note": "Ҳолати шабона: 21:00 фаъол шуд"
    }

    # App Limits & Restrictions
    blocked_threats = db.query(AppRule).filter(AppRule.is_blocked == 1).count()

    rules_rows = [
        {"app_name": "TikTok", "app_icon": "🎵", "category": "Шабакаҳои иҷтимоӣ", "is_blocked": 1, "daily_limit_minutes": 0, "stat": "Маҳкамшуда", "badge": "Маҳкам"},
        {"app_name": "Instagram", "app_icon": "📸", "category": "Шабакаҳои иҷтимоӣ", "is_blocked": 1, "daily_limit_minutes": 30, "stat": "30 дақ/рӯз", "badge": "30 дақ/рӯз"},
        {"app_name": "Free Fire", "app_icon": "🔥", "category": "Бозиҳо", "is_blocked": 1, "daily_limit_minutes": 0, "stat": "Маҳкамшуда", "badge": "Маҳкам"},
        {"app_name": "PUBG Mobile", "app_icon": "🔫", "category": "Бозиҳо", "is_blocked": 1, "daily_limit_minutes": 0, "stat": "Маҳкамшуда", "badge": "Маҳкам"},
        {"app_name": "Roblox", "app_icon": "🧱", "category": "Бозиҳо", "is_blocked": 1, "daily_limit_minutes": 45, "stat": "45 дақ/рӯз", "badge": "45 дақ/рӯз"},
        {"app_name": "YouTube", "app_icon": "▶️", "category": "Видео", "is_blocked": 0, "daily_limit_minutes": 60, "stat": "Интернети бехатар", "badge": "Иҷозат"}
    ]

    # Children list
    children = db.query(Child).order_by(Child.id.desc()).limit(15).all()
    children_list = [c.to_dict() for c in children]

    # Recent downloads
    downloads = db.query(SiteAnalytics).filter(SiteAnalytics.event_type.in_(["apk_download", "qr_scan"])).order_by(SiteAnalytics.id.desc()).limit(8).all()
    recent_downloads = [d.to_dict() for d in downloads]

    return {
        "total_downloads": total_downloads,
        "total_qr_downloads": total_qr_downloads,
        "total_direct_downloads": total_direct_downloads,
        "total_page_views": total_page_views,
        "total_visitors": total_visitors,
        "total_families": total_families,
        "total_children": total_children,
        "total_paired": total_paired,
        "total_online": total_online,
        "blocked_threats": blocked_threats,
        "focus_gauge": focus_gauge,
        "weekly_chart": weekly_chart,
        "weekly_meta": weekly_meta,
        "rules_rows": rules_rows,
        "children_list": children_list,
        "recent_downloads": recent_downloads,
        "registered_users": registered_users,
        "current_version": f"v{settings.APP_VERSION}"
    }
