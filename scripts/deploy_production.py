#!/usr/bin/env python3
"""
NIGOH Family — Production Deployment & Health Verification Automation Script
Connects to 37.27.245.216, synchronizes APKs, modular app directories, templates, and validates health.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path
import pexpect

REMOTE_USER = "dev"
REMOTE_HOST = "37.27.245.216"
REMOTE_PASS = os.environ.get("NIGOH_DEPLOY_PASSWORD", "")
if not REMOTE_PASS:
    raise RuntimeError("NIGOH_DEPLOY_PASSWORD must be provided through the environment")
PROJECT_ROOT = Path(__file__).resolve().parents[1]
ANDROID_PROJECT = Path(os.environ.get(
    "NIGOH_ANDROID_PROJECT",
    str(Path(__file__).resolve().parents[1] / "mobile"),
))
APK_FILENAME = os.environ.get("NIGOH_APK_FILENAME", "NIGOH_Family_Android_v2.14.0.apk")


def build_and_verify_release_apk():
    """Build a production-signed APK and verify its signature before upload."""
    if not ANDROID_PROJECT.is_dir():
        raise RuntimeError(f"Android project directory not found: {ANDROID_PROJECT}")

    flutter = os.environ.get("FLUTTER_BIN", shutil.which("flutter") or "flutter")
    build_env = os.environ.copy()
    java_home = Path(build_env.get("JAVA_HOME", ""))
    if not (java_home / "bin" / "javac").is_file():
        jdk_candidates = [
            Path("/snap/android-studio/244/jbr"),
            Path("/opt/android-studio/jbr"),
        ]
        for candidate in jdk_candidates:
            if (candidate / "bin" / "javac").is_file():
                build_env["JAVA_HOME"] = str(candidate)
                break
    if not (Path(build_env.get("JAVA_HOME", "")) / "bin" / "javac").is_file():
        raise RuntimeError("A full JDK with javac is required for the release build")
    print(f"-> {flutter} clean && {flutter} build apk --release")
    subprocess.run([flutter, "clean"], cwd=ANDROID_PROJECT, check=True, env=build_env)
    subprocess.run([flutter, "build", "apk", "--release"], cwd=ANDROID_PROJECT, check=True, env=build_env)

    apk_path = ANDROID_PROJECT / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not apk_path.is_file():
        raise RuntimeError(f"Release APK was not produced: {apk_path}")

    apksigner = os.environ.get("APKSIGNER") or shutil.which("apksigner")
    if not apksigner:
        sdk_root = Path(
            os.environ.get("ANDROID_HOME")
            or os.environ.get("ANDROID_SDK_ROOT")
            or "/home/munis/Android/Sdk"
        )
        candidates = sorted(sdk_root.glob("build-tools/*/apksigner"), reverse=True)
        if candidates:
            apksigner = str(candidates[0])
    if not apksigner:
        raise RuntimeError("apksigner was not found; refusing to deploy an unverified APK")

    verification = subprocess.run(
        [apksigner, "verify", "--verbose", "--print-certs", str(apk_path)],
        text=True,
        capture_output=True,
        check=False,
    )
    verification_output = f"{verification.stdout}\n{verification.stderr}"
    print(verification_output)
    required_markers = (
        "Verifies",
        "Verified using v2 scheme (APK Signature Scheme v2): true",
        "Verified using v3 scheme (APK Signature Scheme v3): true",
    )
    if verification.returncode != 0 or any(marker not in verification.stdout for marker in required_markers):
        raise RuntimeError("APK signature verification failed; refusing to deploy")
    if "Android Debug" in verification.stdout:
        raise RuntimeError("APK is signed with a debug certificate; refusing to deploy")

    root_target = PROJECT_ROOT / APK_FILENAME
    download_target = PROJECT_ROOT / "app" / "static" / "downloads" / APK_FILENAME
    shutil.copy2(apk_path, root_target)
    shutil.copy2(apk_path, download_target)
    print(f"Verified release APK copied to {root_target} and {download_target}")
REMOTE_PATH = "/home/dev/munis"

def run_ssh(cmd, timeout=3600):
    print(f"-> {cmd}")
    child = pexpect.spawn(cmd, encoding="utf-8", timeout=timeout)
    # Log remote output only. Using ``logfile`` also echoes secrets sent to the
    # pseudo-terminal, which must never appear in CI/deployment logs.
    child.logfile_read = sys.stdout
    while True:
        idx = child.expect(["(?i)password:", pexpect.EOF, pexpect.TIMEOUT], timeout=timeout)
        if idx == 0:
            child.sendline(REMOTE_PASS)
        elif idx == 1:
            break
        elif idx == 2:
            child.close(force=True)
            raise RuntimeError("Remote deployment command timed out")
    child.close()
    status = child.exitstatus
    if status != 0:
        raise RuntimeError(f"Remote deployment command failed with exit code {status}")
    return status

def deploy():
    print("====================================================")
    print("🚀 NIGOH Family — Production Deployment Pipeline")
    print("====================================================")

    build_and_verify_release_apk()

    # 1. Sync entire app/ directory (core, crud, db, models, routers, schemas, templates, static, etc.)
    # Keep production data on the server. Schema initialization is additive and
    # must never replace the live SQLite database with a local copy.
    run_ssh(f'rsync -avzL --exclude "__pycache__" --exclude "*.pyc" --exclude "nigoh.db" --exclude "*.bak" -e "ssh -F /dev/null -o StrictHostKeyChecking=no" app/ {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/app/')

    # 2. Sync root APK and documentation
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" {APK_FILENAME} TECH_STACK.md requirements.txt {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/')

    # Install the pinned runtime dependencies before restarting the API.
    run_ssh(
        f'ssh -F /dev/null -o StrictHostKeyChecking=no {REMOTE_USER}@{REMOTE_HOST} '
        f'{REMOTE_PATH}/venv/bin/pip install -r {REMOTE_PATH}/requirements.txt'
    )

    # 3. Sync deploy configs
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" deploy/ {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/deploy/')

    # 4. Restart server
    run_ssh(f'ssh -F /dev/null -o StrictHostKeyChecking=no {REMOTE_USER}@{REMOTE_HOST} bash {REMOTE_PATH}/restart.sh')

    print("\n✅ Deployment completed successfully!")

if __name__ == "__main__":
    deploy()
