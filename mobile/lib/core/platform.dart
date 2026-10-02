import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Which kind of device the app runs on.
///
/// The Android app is the full product (child blocking, native notification
/// service, APK updater, permission wizard). The desktop app (Windows) is
/// parent-only: no Android channels or mobile-only plugins may be called there.
///
/// In the real app the answer comes from `dart:io` [Platform]. Under
/// `flutter test` (where the host OS is Linux/macOS/Windows) it follows
/// [defaultTargetPlatform], so `debugDefaultTargetPlatformOverride =
/// TargetPlatform.windows` simulates the desktop app; [debugPlatformOverride]
/// forces a platform explicitly.
abstract final class AppPlatform {
  /// Forces the platform (tests). Reset to null in tearDown.
  static TargetPlatform? debugPlatformOverride;

  static final bool _underTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static TargetPlatform get current {
    final forced = debugPlatformOverride;
    if (forced != null) return forced;
    if (kIsWeb || _underTest) return defaultTargetPlatform;
    if (Platform.isAndroid) return TargetPlatform.android;
    if (Platform.isIOS) return TargetPlatform.iOS;
    if (Platform.isWindows) return TargetPlatform.windows;
    if (Platform.isMacOS) return TargetPlatform.macOS;
    if (Platform.isLinux) return TargetPlatform.linux;
    return TargetPlatform.fuchsia;
  }
}

/// The Android phone app (native channels, blocking, notification service).
bool get isAndroidApp =>
    !kIsWeb && AppPlatform.current == TargetPlatform.android;

/// Windows / macOS / Linux desktop app: parent mode only.
bool get isDesktop =>
    !kIsWeb &&
    switch (AppPlatform.current) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
