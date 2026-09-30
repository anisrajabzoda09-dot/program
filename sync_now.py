import pexpect
import sys

def run(cmd):
    print(f"Running: {cmd}")
    child = pexpect.spawn(cmd, encoding="utf-8", timeout=3600)
    child.logfile = sys.stdout
    while True:
        idx = child.expect(["(?i)password:", pexpect.EOF, pexpect.TIMEOUT], timeout=3600)
        if idx == 0:
            child.sendline("J8Gb-ZMPK-DvMF-EEcJ")
        elif idx == 1:
            break
        else:
            print("TIMEOUT")
            break
    child.close()
    print(f"Exit status: {child.exitstatus}")

run("rsync -avz app/core/config.py dev@37.27.245.216:/home/dev/munis/app/core/config.py")
run("rsync -avz app/routers/download.py dev@37.27.245.216:/home/dev/munis/app/routers/download.py")
run("rsync -avz --partial app/static/downloads/NIGOH_Family_Android_v2.9.0_permissions_fixed.apk dev@37.27.245.216:/home/dev/munis/app/static/downloads/")
run("ssh dev@37.27.245.216 'bash /home/dev/munis/restart.sh'")

