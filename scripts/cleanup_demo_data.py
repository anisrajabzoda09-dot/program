#!/usr/bin/env python3
"""Remove the sample data that older builds seeded into the database.

Only rows created by the old seed code are touched:
  * the four invented reviews (matched by exact author name)
  * the five sample children (matched by their seeded pairing codes and
    not linked to any real user)

Dry run by default — it only prints what it would delete.
Run with --apply to delete. A copy of the database is written first.

    python3 scripts/cleanup_demo_data.py            # show
    python3 scripts/cleanup_demo_data.py --apply    # delete
"""
import shutil
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[1] / "app" / "nigoh.db"

FAKE_REVIEW_AUTHORS = (
    "Фарҳод Қосимов",
    "Мадина Саидова",
    "Рустам Назаров",
    "Шаҳноза Алиева",
)
SAMPLE_CHILD_CODES = (
    "NIGOH-7412-X",
    "NIGOH-3918-X",
    "NIGOH-8821-X",
    "NIGOH-1049-X",
    "NIGOH-5524-X",
)


def _marks(values) -> str:
    """Build the SQLite placeholders needed for a sequence of parameters."""

    return ",".join("?" * len(values))


def main() -> None:
    """Preview or safely delete recognized seed rows after backing up the database."""

    apply = "--apply" in sys.argv
    conn = sqlite3.connect(DB_PATH)
    reviews = conn.execute(
        f"SELECT id, author_name FROM reviews WHERE author_name IN ({_marks(FAKE_REVIEW_AUTHORS)})",
        FAKE_REVIEW_AUTHORS,
    ).fetchall()
    children = conn.execute(
        f"SELECT id, name FROM children WHERE pairing_code IN ({_marks(SAMPLE_CHILD_CODES)}) "
        "AND parent_id IS NULL AND user_id IS NULL",
        SAMPLE_CHILD_CODES,
    ).fetchall()
    print(f"Database: {DB_PATH}")
    print(f"Sample reviews:  {len(reviews)} {[r[1] for r in reviews]}")
    print(f"Sample children: {len(children)} {[c[1] for c in children]}")
    if not apply:
        print("Dry run. Re-run with --apply to delete these rows.")
        return
    if not reviews and not children:
        print("Nothing to delete.")
        return
    backup = DB_PATH.with_name(f"nigoh-{datetime.now():%Y%m%d-%H%M%S}.db.bak")
    shutil.copy2(DB_PATH, backup)
    print(f"Backup written: {backup}")
    child_ids = [c[0] for c in children]
    with conn:
        if reviews:
            conn.execute(
                f"DELETE FROM reviews WHERE id IN ({_marks(reviews)})", [r[0] for r in reviews]
            )
        if child_ids:
            for table in ("app_rules", "app_usage_daily", "chat_messages"):
                try:
                    conn.execute(f"DELETE FROM {table} WHERE child_id IN ({_marks(child_ids)})", child_ids)
                except sqlite3.OperationalError:
                    pass  # table or column absent in this schema version
            conn.execute(f"DELETE FROM children WHERE id IN ({_marks(child_ids)})", child_ids)
    print("Deleted.")


if __name__ == "__main__":
    main()
