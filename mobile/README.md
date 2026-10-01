# NIGOH Family — Android app

Flutter app (package `tj.nigoh.nigoh_family_parent`). One APK for both phones; the role (parent / child) is chosen after sign-in. Talks only to the NIGOH server (`NIGOH_API_BASE_URL`, default https://nigohfamily.qobus.tj) — no Firebase.

## Layout

| Path | What |
|---|---|
| `lib/core/api.dart` | HTTP client; every error becomes `ApiException` with a Tajik message |
| `lib/core/session.dart` | Sign-in state, token in SharedPreferences (`nigoh.token`) |
| `lib/core/models.dart` | Snapshot models; `ChildApp.toNativeRule` folds bonus, always-allowed, bedtime and study mode |
| `lib/core/notify_bridge.dart` | Bridge to the native notification service |
| `lib/features/parent/` | Family overview, app rules, map, requests, reports, study mode |
| `lib/features/child/` | Child home, sync engine (`child_sync.dart`), «Қоидаҳои ман», SOS |
| `lib/features/chat/`, `call/` | Chat and WebRTC voice calls |
| `lib/features/settings/` | Settings, parent PIN, one-tap update |
| `android/.../kotlin/` | App blocker (Accessibility + usage stats + overlay), `NotifyService` (long-poll notifications, SOS alarm, call ring), `AppUpdater` (signature-checked self-update) |

## Develop

The Dart analyzer crashes on non-ASCII paths, so work from an ASCII directory (or a copy) when running analysis:

```bash
flutter pub get
flutter analyze
flutter test
```

`integration_local/e2e_test.dart` runs the API client against a local server on port 8765.

## Release

1. Bump `version:` in `pubspec.yaml` (name + build number).
2. `flutter build apk --release` — signing comes from `android/key.properties` and `android/keystore/` (not in git).
3. Check: `apksigner verify --print-certs` must show the same certificate as before, otherwise phones cannot update in place.
4. Copy the APK to `app/static/downloads/NIGOH_Family_Android_vX.Y.Z.apk`, update `APP_VERSION` / `APP_VERSION_CODE` and `APK_CANDIDATES` in `app/core/config.py`, deploy.

## Notes

- Blocking rules are enforced on the phone and keep working offline; the child syncs rules every ~15 s.
- Voice calls use public STUN servers; set `TURN_URLS`/`TURN_USERNAME`/`TURN_PASSWORD` on the server for reliable calls on mobile networks.
- Android 13+: sideloaded apps need «Allow restricted settings» (App info → ⋮) before Accessibility can be enabled.
