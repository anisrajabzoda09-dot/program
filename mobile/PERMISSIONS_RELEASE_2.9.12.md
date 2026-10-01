# Android permission repair — 2.9.12 (30)

The supplied phone reports “App was denied access / Controlled by restricted
setting” for display-over-other-apps. The application cannot grant or bypass
this OS restriction. Android permission grants remain separate; the release
provides a single setup screen, not a universal permission.

## Changes

- Removed Settings interception based only on UsageEvents activity names:
  these events do not expose the target package URI. The old logic could
  interrupt app info and permissions for unrelated apps.
- Added a reusable, localized permission center with per-permission actions,
  a next-step button, restriction guidance, retryable load errors and refresh
  after returning from system settings.
- Separated location permission, GPS service status and background location.
  Camera and Device Admin are identified as optional.
- Device Admin alone no longer implies that application blocking is ready.
- Resume the monitor after the user returns with required special permissions.
- Catch overlay creation failure if permission is revoked during the check.
- Use the pre-Android-10 AppOps API and pre-Android-8 overlay window type on
  supported older phones.

## Verification and limits

Seven Flutter tests passed, including new permission-screen regressions:
admin-only state, settings opening and lifecycle refresh, native error handling.
Flutter analysis reported no issues.

Release APK compiled successfully with versionCode 30 and verified v2/v3
signatures. SHA-256:
`e1838f3ca5106e501ea67ebaa8a6b6909da1da3aec66dd769e9ff2b11070e949`.
The uploaded server APK matched this checksum. Backend bundle tests,
strict version checks and the SEO smoke test passed.

These tests do not prove actual app blocking, OEM Settings behavior or
uninstall prevention on a real phone. No Android device was connected.
Legacy Device Admin cannot guarantee PIN enforcement over the OS uninstall
flow. Existing in-app PIN verification does not change this OS limitation.

No arbitrary new product features, universal consent mechanism, or Device Owner
enrollment were implemented by this compatibility repair.

References:
- https://support.google.com/android/answer/12623953
- https://developer.android.com/reference/android/app/usage/UsageEvents.Event
