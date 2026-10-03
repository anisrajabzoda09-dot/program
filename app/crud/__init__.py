"""Файл: амалиёти пойгоҳи додаҳо барои бахши `__init__`."""

from app.crud.crud_user import (
    get_user_by_email,
    get_user_by_id,
    create_user,
    update_user_role,
    upsert_google_user,
    get_registered_users
)
from app.crud.crud_child import (
    ensure_default_child_apps,
    create_or_get_child_for_user,
    get_child_for_user,
    get_child_by_pairing_code,
    pair_child_with_parent,
    get_children_list,
    update_child_profile,
    delete_child
)
from app.crud.crud_rules import (
    get_child_app_rules,
    toggle_app_rule,
    set_app_rule_limit,
    count_blocked_threats
)
from app.crud.crud_chat import (
    get_child_messages,
    send_message
)
from app.crud.crud_analytics import (
    log_analytics_event,
    get_admin_dashboard_data
)

__all__ = [
    "get_user_by_email",
    "get_user_by_id",
    "create_user",
    "update_user_role",
    "upsert_google_user",
    "get_registered_users",
    "ensure_default_child_apps",
    "create_or_get_child_for_user",
    "get_child_for_user",
    "get_child_by_pairing_code",
    "pair_child_with_parent",
    "get_children_list",
    "update_child_profile",
    "delete_child",
    "get_child_app_rules",
    "toggle_app_rule",
    "set_app_rule_limit",
    "count_blocked_threats",
    "get_child_messages",
    "send_message",
    "log_analytics_event",
    "get_admin_dashboard_data"
]
