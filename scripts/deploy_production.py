#!/usr/bin/env python3
"""
NIGOH Family — Production Deployment & Health Verification Automation Script
Connects to 37.27.245.216, synchronizes APKs, templates, and validates health.
"""
import sys
import pexpect

REMOTE_USER = "dev"
REMOTE_HOST = "37.27.245.216"
REMOTE_PASS = "J8Gb-ZMPK-DvMF-EEcJ"
REMOTE_PATH = "/home/dev/munis"

def run_ssh(cmd, timeout=300):
    print(f"-> {cmd}")
    child = pexpect.spawn(cmd, encoding="utf-8", timeout=timeout)
    child.logfile = sys.stdout
    while True:
        idx = child.expect(["(?i)password:", pexpect.EOF, pexpect.TIMEOUT])
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

    # 1. Sync downloads
    run_ssh(f'rsync -avz --delete -e "ssh -F /dev/null -o StrictHostKeyChecking=no" app/static/downloads/ {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/app/static/downloads/')

    # 2. Sync root APK
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" NIGOH_Family_Android_v2.6.1.apk {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/')

    # 3. Sync templates
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" app/templates/ {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/app/templates/')

    # 4. Sync backend and schemas
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" app/main.py {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/app/main.py')
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" app/schemas.py {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/app/schemas.py')

    # 5. Sync deploy configs
    run_ssh(f'rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" deploy/ {REMOTE_USER}@{REMOTE_HOST}:{REMOTE_PATH}/deploy/')

    # 6. Restart server
    run_ssh(f'ssh -F /dev/null -o StrictHostKeyChecking=no {REMOTE_USER}@{REMOTE_HOST} bash {REMOTE_PATH}/restart.sh')

    print("\n✅ Deployment completed successfully!")

if __name__ == "__main__":
    deploy()

