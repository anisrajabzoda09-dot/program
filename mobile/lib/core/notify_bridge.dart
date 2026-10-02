import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api.dart';
import 'platform.dart';
import '../l10n/l10n.dart';

/// What the user tapped in a notification posted by the native NotifyService.
///
/// [kind] is the server event kind: 'message', 'sos', 'call', 'time_request',
/// 'time_decision', 'low_battery', 'offline', 'new_app', 'missed_call'.
class LaunchAction {
  const LaunchAction({
    required this.kind,
    this.childId,
    this.callId,
    this.peerName,
    this.acceptCall = false,
    this.fullScreen = false,
  });

  /// Parses the map sent by MainActivity (`getLaunchAction` / `launch`).
  static LaunchAction? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    if (kind is! String || kind.isEmpty) return null;
    int? asInt(Object? v) => v is int
        ? v
        : v is num
        ? v.toInt()
        : v is String
        ? int.tryParse(v)
        : null;
    final peer = raw['peerName'];
    return LaunchAction(
      kind: kind,
      childId: asInt(raw['childId']),
      callId: asInt(raw['callId']),
      peerName: peer is String && peer.isNotEmpty ? peer : null,
      acceptCall: raw['acceptCall'] == true,
      fullScreen: raw['fullScreen'] == true,
    );
  }

  final String kind;
  final int? childId;
  final int? callId;
  final String? peerName;

  /// «Қабул» was pressed on the incoming-call notification.
  final bool acceptCall;

  /// Opened automatically by a full-screen intent (locked screen), not a tap.
  /// For SOS this means the alarm is still ringing.
  final bool fullScreen;

  @override
  String toString() =>
      'LaunchAction($kind, child: $childId, call: $callId, accept: $acceptCall)';
}

/// Notification permission state reported by Android.
class NotifyPermissions {
  const NotifyPermissions({
    required this.notifications,
    required this.fullScreen,
  });
  final bool notifications;

  /// Android 14+: may show SOS alarms / calls over the lock screen.
  final bool fullScreen;
  bool get all => notifications && fullScreen;
}

/// Bridge to the native NotifyService (foreground long-poll of
/// /api/mobile/v3/events → Android notifications, no Firebase).
abstract final class NotifyBridge {
  static const channel = MethodChannel('tj.nigoh/notify');

  /// Set when the app is opened from a notification. Consumers should reset
  /// it to null after handling.
  static final ValueNotifier<LaunchAction?> launch = ValueNotifier(null);

  /// Last bridge error (shown in Settings), null when fine.
  static final ValueNotifier<String?> lastError = ValueNotifier(null);

  static bool _listening = false;

  /// Android only: the desktop app runs its own Dart loop
  /// (features/desktop/desktop_notifications.dart).
  static bool get _supported => isAndroidApp;

  /// Starts listening for launches from notifications and picks up the one
  /// that cold-started the app. Idempotent; [start] calls it.
  static Future<void> init() async {
    if (!_supported) return;
    if (!_listening) {
      _listening = true;
      channel.setMethodCallHandler((call) async {
        if (call.method == 'launch') {
          final action = LaunchAction.fromMap(call.arguments);
          if (action != null) launch.value = action;
        }
        return null;
      });
    }
    try {
      final raw = await channel.invokeMethod<Object?>('getLaunchAction');
      final action = LaunchAction.fromMap(raw);
      if (action != null) launch.value = action;
    } on MissingPluginException {
      // Not running inside the Android app (tests / other platforms).
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Огоҳиномаҳо кор накарданд.');
    }
  }

  /// Starts/updates the native service. The service reads token and role from
  /// shared preferences itself; only the server address is passed.
  static Future<void> start(NigohApi api) async {
    if (!_supported) return;
    await init();
    try {
      await channel.invokeMethod<Object?>('start', {'baseUrl': api.baseUrl});
      lastError.value = null;
    } on MissingPluginException {
      // Not running inside the Android app.
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Хизмати огоҳиномаҳо оғоз нашуд.');
    }
  }

  static Future<void> stop() async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<Object?>('stop');
    } on MissingPluginException {
      // Not running inside the Android app.
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Хизмати огоҳиномаҳо қатъ нашуд.');
    }
  }

  /// Silences an SOS alarm / call ringtone that the service is playing.
  static Future<void> stopRinging() async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<Object?>('stopRinging');
    } on MissingPluginException {
      // Not running inside the Android app.
    } on PlatformException catch (e) {
      lastError.value = e.message;
    }
  }

  /// Null when the status could not be read (see [lastError]).
  static Future<NotifyPermissions?> permissionStatus() async {
    if (!_supported) return null;
    try {
      final raw = await channel.invokeMapMethod<String, Object?>(
        'permissionStatus',
      );
      if (raw == null) return null;
      return NotifyPermissions(
        notifications: raw['notifications'] == true,
        fullScreen: raw['fullScreen'] != false,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Ҳолати огоҳиномаҳо маълум нашуд.');
      return null;
    }
  }

  static Future<void> openFullScreenSettings() async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<Object?>('openFullScreenSettings');
    } on MissingPluginException {
      // Not running inside the Android app.
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Танзимот кушода нашуд.');
    }
  }

  /// Asks for POST_NOTIFICATIONS and, on Android 14+, explains and opens the
  /// full-screen-intent setting (needed for the SOS alarm and calls).
  /// Returns true when everything needed is granted.
  static Future<bool> ensurePermissions(BuildContext context) async {
    if (!_supported) return true;
    var status = await permissionStatus();
    if (status == null) return false;
    if (!status.notifications) {
      try {
        final result = await Permission.notification.request();
        if (result.isPermanentlyDenied) await openAppSettings();
      } on MissingPluginException {
        return false;
      } on PlatformException catch (e) {
        lastError.value = e.message ?? tr('Иҷозати огоҳиномаҳо дода нашуд.');
      }
      status = await permissionStatus() ?? status;
    }
    if (!status.fullScreen && context.mounted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.notifications_active_outlined),
          title: Text(tr('Огоҳиномаҳо дар экрани пурра')),
          content: Text(
            tr(
              'Барои он ки ҳушдори SOS ва зангҳо ҳатто дар экрани қулфшуда '
              'намоён шаванд, ба NIGOH иҷозати «огоҳиномаҳои экрани пурра» диҳед.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Баъдтар')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('Кушодани танзимот')),
            ),
          ],
        ),
      );
      if (open == true) await openFullScreenSettings();
    }
    return status.all;
  }

  @visibleForTesting
  static void resetForTest() {
    _listening = false;
    launch.value = null;
    lastError.value = null;
  }
}
