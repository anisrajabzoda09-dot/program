#!/usr/bin/env python3
"""Back up only the production NIGOH Family project to a local disk."""

import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shlex
import sqlite3
import subprocess

from deploy_production import REMOTE_HOST, REMOTE_PATH, REMOTE_USER, SSH_OPTS, askpass_env


def run(command: list[str], env: dict, capture: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        command,
        check=True,
        env=env,
        stdin=subprocess.DEVNULL,
        text=capture,
        capture_output=capture,
    )


def remote_command(target: str, arguments: list[str]) -> list[str]:
    command = " ".join(shlex.quote(argument) for argument in arguments)
    return [*shlex.split(SSH_OPTS), target, command]


def write_checksums(root: Path) -> tuple[int, int]:
    rows = []
    total_bytes = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.name == "SHA256SUMS.txt":
            continue
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
        size = path.stat().st_size
        total_bytes += size
        rows.append(f"{digest.hexdigest()}  {path.relative_to(root)}")
    (root / "SHA256SUMS.txt").write_text("\n".join(rows) + "\n", encoding="utf-8")
    return len(rows), total_bytes


def backup(destination: Path) -> None:
    if destination.exists():
        raise RuntimeError(f"Backup destination already exists: {destination}")
    destination.mkdir(parents=True)
    project_destination = destination / "project"
    database_destination = destination / "database"
    database_destination.mkdir()

    target = f"{REMOTE_USER}@{REMOTE_HOST}"
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    remote_database = f"{REMOTE_PATH}/app/nigoh.db"
    remote_snapshot = f"/tmp/nigoh-family-{stamp}.sqlite"
    env = askpass_env()
    try:
        preflight = run(remote_command(target, [
            "sh", "-c",
            f"test -d {shlex.quote(REMOTE_PATH)} && du -sh {shlex.quote(REMOTE_PATH)} && "
            f"find {shlex.quote(REMOTE_PATH)} -xdev -type l -printf '%p -> %l\\n'",
        ]), env, capture=True)
        (destination / "REMOTE_PREFLIGHT.txt").write_text(preflight.stdout, encoding="utf-8")

        sqlite_backup = (
            "import sqlite3,sys;"
            "source=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True);"
            "target=sqlite3.connect(sys.argv[2]);"
            "source.backup(target);target.close();source.close()"
        )
        run(remote_command(target, [
            f"{REMOTE_PATH}/venv/bin/python", "-c", sqlite_backup,
            remote_database, remote_snapshot,
        ]), env)

        run([
            "rsync", "-az", "--partial", "--timeout=180",
            "-e", SSH_OPTS,
            f"{target}:{REMOTE_PATH}/", f"{project_destination}/",
        ], env)
        run([
            "rsync", "-az", "--partial", "--timeout=180",
            "-e", SSH_OPTS,
            f"{target}:{remote_snapshot}", str(database_destination / "nigoh.db"),
        ], env)
    finally:
        try:
            run(remote_command(target, ["rm", "-f", remote_snapshot]), env)
        finally:
            os.unlink(env["SSH_ASKPASS"])

    with sqlite3.connect(database_destination / "nigoh.db") as database:
        integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
    if integrity != "ok":
        raise RuntimeError(f"SQLite backup integrity check failed: {integrity}")

    file_count, total_bytes = write_checksums(destination)
    metadata = {
        "created_at": datetime.now().astimezone().isoformat(),
        "source": f"{target}:{REMOTE_PATH}",
        "scope": "NIGOH Family project only",
        "consistent_database": "database/nigoh.db",
        "sqlite_integrity": integrity,
        "files": file_count,
        "bytes": total_bytes,
    }
    (destination / "BACKUP.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, ensure_ascii=False))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--destination",
        type=Path,
        default=Path("/mnt/games/backup") / f"NIGOH_Family_{datetime.now():%Y-%m-%d_%H%M%S}",
    )
    arguments = parser.parse_args()
    backup(arguments.destination.resolve())


if __name__ == "__main__":
    main()
