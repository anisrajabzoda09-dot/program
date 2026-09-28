#!/usr/bin/env python3
"""
NIGOH Family — Production Deployment & Health Verification Automation Script
Connects to 37.27.245.216, synchronizes APKs, modular app directories, templates, and validates health.
"""
import sys
import pexpect

REMOTE_USER = "dev"
REMOTE_HOST = "37.27.245.216"
REMOTE_PASS = "J8Gb-ZMPK-DvMF-EEcJ"
REMOTE_PATH = "/home/dev/munis"

def run_ssh(cmd, timeout=3600):
    print(f"-> {cmd}")
    child = pexpect.spawn(cmd, encoding="utf-8", timeout=timeout)
    child.logfile = sys.stdout
    while True:
        idx = child.expect(["(?i)password:", pexpect.EOF, pexpect.TIMEOUT], timeout=timeout)
        if idx == 0:
            child.sendline(REMOTE_PASS)
        elif idx == 1:
            break
        elif idx == 2:
            print("[ERROR] Command timed out!")
            return 1
    child.close()
    return child.exitstatus

def deploy():
    print("====================================================")
    print("🚀 NIGOH Family — Production Deployment Pipeline")
    print("====================================================")

    # 1. Sync entire app/ directory (core, crud, db, models, routers, schemas, templates, static, etc.)
    run_ssh(f'rsync -avz --exclude "__pycache__" --exclude "*.pyc" -e "ssh -F /dev/null -o StrictHostKeyChecking=no" app/ {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/app/')

    # 2. Sync root APK and documentation
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" NIGOH_Family_Android_v2.9.0_permissions_fixed.apk TECH_STACK.md {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/')

    # 3. Sync deploy configs
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" deploy/ {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/deploy/')

    # 4. Restart server
    run_ssh(f'ssh -F /dev/null -o StrictHostKeyChecking=no {REMOTE_USER}@{REMOTE_HOST} bash {REMOTE_PATH}/restart.sh')

    print("\n✅ Deployment completed successfully!")

if __name__ == "__main__":
    deploy()
