#!/usr/bin/env python3
"""One-time, scoped cleanup for NIGOH user accounts and dependent data."""

from __future__ import annotations

import argparse
import datetime as dt
import sqlite3
from pathlib import Path


ACCOUNT_TABLES = ("users", "children", "app_rules", "chat_messages")
DELETE_ORDER = ("app_rules", "chat_messages", "children", "users")


def counts(connection: sqlite3.Connection) -> dict[str, int]:
    result: dict[str, int] = {}
    available = {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }
    for table in ACCOUNT_TABLES:
        result[table] = (
            connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            if table in available
            else 0
        )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("database", type=Path)
    parser.add_argument("--delete", action="store_true")
    args = parser.parse_args()

    database = args.database.resolve()
    if database.name != "nigoh.db" or database.parent.name != "app":
        raise SystemExit("Refusing to touch a database outside the NIGOH app folder")

    connection = sqlite3.connect(database)
    before = counts(connection)
    print("before", before)
    if not args.delete:
        connection.close()
        return 0

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = database.with_name(f"nigoh.db.before-user-delete-{stamp}.bak")
    with sqlite3.connect(backup) as backup_connection:
        connection.backup(backup_connection)

    try:
        connection.execute("PRAGMA foreign_keys = OFF")
        connection.execute("BEGIN IMMEDIATE")
        available = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        for table in DELETE_ORDER:
            if table in available:
                connection.execute(f'DELETE FROM "{table}"')
        if "sqlite_sequence" in available:
            placeholders = ",".join("?" for _ in ACCOUNT_TABLES)
            connection.execute(
                f"DELETE FROM sqlite_sequence WHERE name IN ({placeholders})",
                ACCOUNT_TABLES,
            )
        connection.commit()
    except Exception:
        connection.rollback()
        raise

    after = counts(connection)
    connection.close()
    if any(after.values()):
        raise SystemExit(f"Cleanup verification failed: {after}")
    print("after", after)
    print("backup", backup)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
