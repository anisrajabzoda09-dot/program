// Файл: пайванди notification-и Android бо Flutter.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api.dart';
import '../l10n/l10n.dart';

/// Додаҳо ва рафтори марбут ба пайванди notification-и Android бо Flutter-ро ифода мекунад.
class LaunchAction {
  const LaunchAction({
    required this.kind,
    this.childId,
    this.callId,
    this.peerName,
    this.acceptCall = false,
    this.fullScreen = false,
  });

  /// fromMap мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад.
  static LaunchAction? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    if (kind is! String || kind.isEmpty) return null;
    /// asInt мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад.
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

  /// Қимати acceptCall-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад.
  final bool acceptCall;

  /// Қимати fullScreen-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад.
  final bool fullScreen;

  /// Намоиши матнии LaunchAction-ро барои log бармегардонад.
  @override
  String toString() =>
      'LaunchAction($kind, child: $childId, call: $callId, accept: $acceptCall)';
}

/// Додаҳо ва рафтори марбут ба пайванди notification-и Android бо Flutter-ро ифода мекунад.
class NotifyPermissions {
  const NotifyPermissions({
    required this.notifications,
    required this.fullScreen,
  });
  final bool notifications;

  /// Қимати fullScreen-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад.
  final bool fullScreen;
  /// Қимати ҳисобшудаи all-ро аз ҳолати ҷорӣ бармегардонад.
  bool get all => notifications && fullScreen;
}

/// Ин қадам ҷавоби server ё хатои API-ро коркард мекунад.
abstract final class NotifyBridge {
  static const channel = MethodChannel('tj.nigoh/notify');

  /// Қимати launch-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад.
  static final ValueNotifier<LaunchAction?> launch = ValueNotifier(null);

  /// Қимати lastError-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад.
  static final ValueNotifier<String?> lastError = ValueNotifier(null);

  static bool _listening = false;

  /// Қимати _supported-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад.
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// init мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад.
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
      // Дар платформаи бе plugin амали оғози огоҳинома вуҷуд надорад.
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Огоҳиномаҳо кор накарданд.');
    }
  }

  /// start раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  static Future<void> start(NigohApi api) async {
    if (!_supported) return;
    await init();
    try {
      await channel.invokeMethod<Object?>('start', {'baseUrl': api.baseUrl});
      lastError.value = null;
    } on MissingPluginException {
      // Дар платформаи бе plugin хизмати огоҳинома оғоз намешавад.
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Хизмати огоҳиномаҳо оғоз нашуд.');
    }
  }

  /// stop раванди фаъолро қатъ карда, захираҳои онро озод мекунад.
  static Future<void> stop() async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<Object?>('stop');
    } on MissingPluginException {
      // Дар платформаи бе plugin хизмати огоҳинома барои қатъ кардан нест.
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Хизмати огоҳиномаҳо қатъ нашуд.');
    }
  }

  /// stopRinging раванди фаъолро қатъ карда, захираҳои онро озод мекунад.
  static Future<void> stopRinging() async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<Object?>('stopRinging');
    } on MissingPluginException {
      // Дар платформаи бе plugin садои занг барои қатъ кардан нест.
    } on PlatformException catch (e) {
      lastError.value = e.message;
    }
  }

  /// permissionStatus мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад.
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

  /// openFullScreenSettings экран, dialog ё танзимоти мувофиқро мекушояд.
  static Future<void> openFullScreenSettings() async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<Object?>('openFullScreenSettings');
    } on MissingPluginException {
      // Дар платформаи бе plugin танзими full-screen intent кушода намешавад.
    } on PlatformException catch (e) {
      lastError.value = e.message ?? tr('Танзимот кушода нашуд.');
    }
  }

  /// ensurePermissions дурустӣ ва шартҳои зарурии додаҳоро месанҷад.
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

  /// resetForTest мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад.
  @visibleForTesting
  static void resetForTest() {
    _listening = false;
    launch.value = null;
    lastError.value = null;
  }
}
