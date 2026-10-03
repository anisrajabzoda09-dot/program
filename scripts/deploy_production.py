#!/usr/bin/env python3
"""Файл: deploy кардани website, API ва APK-и release ба production."""
import os
import shutil
import stat
import subprocess
import tempfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
REMOTE_PATH = "/home/dev/munis"


def load_env_file(path: Path) -> None:
    """Барои гирифтан ё санҷидани load env file истифода мешавад."""
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


load_env_file(PROJECT_ROOT / ".env.deploy")

REMOTE_USER = os.environ.get("NIGOH_DEPLOY_USER", "dev")
REMOTE_HOST = os.environ.get("NIGOH_DEPLOY_HOST", "37.27.245.216")
REMOTE_PASS = os.environ.get("NIGOH_DEPLOY_PASSWORD", "")
ANDROID_PROJECT = Path(os.environ.get("NIGOH_ANDROID_PROJECT", str(PROJECT_ROOT / "mobile")))
APK_FILENAME = os.environ.get("NIGOH_APK_FILENAME", "NIGOH_Family_Android_v2.19.0.apk")
DOWNLOADS = PROJECT_ROOT / "app" / "static" / "downloads"
SSH_OPTS = "ssh -F /dev/null -o StrictHostKeyChecking=accept-new"


def find_apksigner() -> str:
    """Барои гирифтан ё санҷидани find apksigner истифода мешавад."""
    apksigner = os.environ.get("APKSIGNER") or shutil.which("apksigner")
    if apksigner:
        return apksigner
    sdk_root = Path(
        os.environ.get("ANDROID_HOME")
        or os.environ.get("ANDROID_SDK_ROOT")
        or Path.home() / "Android" / "Sdk"
    )
    candidates = sorted(sdk_root.glob("build-tools/*/apksigner"), reverse=True)
    if not candidates:
        raise RuntimeError("apksigner was not found; refusing to deploy an unverified APK")
    return str(candidates[0])


def verify_apk_signature(apk_path: Path) -> None:
    """Барои гирифтан ё санҷидани verify apk signature истифода мешавад."""
    result = subprocess.run(
        [find_apksigner(), "verify", "--verbose", "--print-certs", str(apk_path)],
        text=True, capture_output=True, check=False,
    )
    required = (
        "Verifies",
        "Verified using v2 scheme (APK Signature Scheme v2): true",
        "Verified using v3 scheme (APK Signature Scheme v3): true",
    )
    if result.returncode != 0 or any(marker not in result.stdout for marker in required):
        raise RuntimeError(f"APK signature verification failed; refusing to deploy:\n{result.stdout}{result.stderr}")
    if "Android Debug" in result.stdout:
        raise RuntimeError("APK is signed with a debug certificate; refusing to deploy")
    print(f"APK signature OK: {apk_path.name}")


def find_jdk(env: dict) -> None:
    """Барои гирифтан ё санҷидани find jdk истифода мешавад."""
    if (Path(env.get("JAVA_HOME", "")) / "bin" / "javac").is_file():
        return
    for candidate in ("/snap/android-studio/current/jbr", "/opt/android-studio/jbr"):
        if (Path(candidate) / "bin" / "javac").is_file():
            env["JAVA_HOME"] = candidate
            return
    raise RuntimeError("A full JDK with javac is required for the release build")


def build_release_apk() -> Path:
    """Маълумоти ёрирасони build release apk-ро омода карда, ба caller бармегардонад."""
    if not ANDROID_PROJECT.is_dir():
        raise RuntimeError(f"Android project directory not found: {ANDROID_PROJECT}")
    flutter = os.environ.get("FLUTTER_BIN", shutil.which("flutter") or "flutter")
    env = os.environ.copy()
    find_jdk(env)
    print(f"-> flutter build apk --release ({ANDROID_PROJECT})")
    subprocess.run([flutter, "build", "apk", "--release"], cwd=ANDROID_PROJECT, check=True, env=env)
    built = ANDROID_PROJECT / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not built.is_file():
        raise RuntimeError(f"Release APK was not produced: {built}")
    verify_apk_signature(built)
    target = DOWNLOADS / APK_FILENAME
    shutil.copy2(built, target)
    print(f"Copied to {target}")
    return target


def prepare_apk() -> Path:
    """Маълумоти ёрирасони prepare apk-ро омода карда, ба caller бармегардонад."""
    if os.environ.get("NIGOH_SKIP_BUILD") == "1":
        apk = DOWNLOADS / APK_FILENAME
        if not apk.is_file():
            raise RuntimeError(f"NIGOH_SKIP_BUILD=1 but {apk} does not exist")
        verify_apk_signature(apk)
        return apk
    return build_release_apk()


def askpass_env() -> dict:
    """askpass env-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    if not REMOTE_PASS:
        raise RuntimeError("NIGOH_DEPLOY_PASSWORD is missing (set it or create .env.deploy)")
    fd, path = tempfile.mkstemp(prefix="nigoh-askpass-", suffix=".sh")
    with os.fdopen(fd, "w") as fh:
        fh.write('#!/bin/sh\nprintf "%s\\n" "$NIGOH_DEPLOY_PASSWORD"\n')
    os.chmod(path, stat.S_IRWXU)
    env = os.environ.copy()
    env.update(SSH_ASKPASS=path, SSH_ASKPASS_REQUIRE="force", DISPLAY=env.get("DISPLAY", ":0"))
    return env


def run(cmd: str, env: dict) -> None:
    """Маълумоти ёрирасони run-ро омода карда, ба caller бармегардонад."""
    print(f"-> {cmd}")
    subprocess.run(cmd, shell=True, check=True, env=env, cwd=PROJECT_ROOT, stdin=subprocess.DEVNULL)


def deploy() -> None:
    """Ҷараёни асосии deploy-ро иҷро карда, хатоҳоро назорат мекунад."""
    print("NIGOH Family — production deploy")
    prepare_apk()
    env = askpass_env()
    target = f"{REMOTE_USER}@{REMOTE_HOST}"
    try:
        # App code, templates and static files. -L uploads the APKs behind the
        # downloads symlink. The live database and backups stay on the server.
        run(f'rsync -azL --exclude "__pycache__" --exclude "*.pyc" --exclude "nigoh.db" '
            f'--exclude "*.bak" -e "{SSH_OPTS}" app/ {target}:{REMOTE_PATH}/app/', env)
        run(f'rsync -az -e "{SSH_OPTS}" requirements.txt TECH_STACK.md {target}:{REMOTE_PATH}/', env)
        run(f'rsync -az -e "{SSH_OPTS}" deploy/ {target}:{REMOTE_PATH}/deploy/', env)
        run(f'{SSH_OPTS} {target} "{REMOTE_PATH}/venv/bin/pip install -q -r {REMOTE_PATH}/requirements.txt"', env)
        run(f'{SSH_OPTS} {target} "bash {REMOTE_PATH}/restart.sh"', env)
    finally:
        os.unlink(env["SSH_ASKPASS"])
    print("Deployment completed.")


if __name__ == "__main__":
    deploy()
