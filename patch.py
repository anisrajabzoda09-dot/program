with open("app/core/config.py", "r") as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if 'APP_VERSION: str = "2.0.0"' in line:
        lines[i] = '    APP_VERSION: str = "2.9.0"\n'
    elif 'APP_VERSION_CODE: int = 20' in line:
        lines[i] = '    APP_VERSION_CODE: int = 21\n'
    elif 'APK_CANDIDATES = [' in line:
        lines.insert(i + 1, '        "NIGOH_Family_Android_v2.9.0_permissions_fixed.apk",\n')
        break
with open("app/core/config.py", "w") as f:
    f.writelines(lines)

with open("app/routers/download.py", "r") as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if 'root_apk = os.path.join(settings.BASE_DIR, "Nigoh_Family_v2.0.0.apk")' in line:
        lines[i] = '    root_apk = os.path.join(settings.BASE_DIR, "NIGOH_Family_Android_v2.9.0_permissions_fixed.apk")\n'
    elif 'filename="Nigoh_Family_v2.0.0.apk"' in line:
        lines[i] = '            filename="NIGOH_Family_Android_v2.9.0_permissions_fixed.apk"\n'
with open("app/routers/download.py", "w") as f:
    f.writelines(lines)
