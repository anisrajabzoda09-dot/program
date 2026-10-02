import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/home_target.dart';
import '../../l10n/l10n.dart';
import '../call/call_screen.dart';

/// One server event (`/api/mobile/v3/events`) as the desktop app shows it.
class DesktopEvent {
  const DesktopEvent({
    required this.id,
    required this.kind,
    this.childId,
    this.childName,
    this.title = '',
    this.body = '',
    this.data = const {},
  });

  static DesktopEvent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as num?)?.toInt();
    final kind = raw['kind']?.toString() ?? '';
    if (id == null || kind.isEmpty) return null;
    String? str(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty || s == 'null' ? null : s;
    }

    final data = raw['data'];
    return DesktopEvent(
      id: id,
      kind: kind,
      childId: (raw['child_id'] as num?)?.toInt(),
      childName: str(raw['child_name']),
      title: str(raw['title']) ?? '',
      body: str(raw['body']) ?? '',
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }

  final int id;
  final String kind;
  final int? childId;
  final String? childName;

  /// Server texts (Tajik); used when structured [data] is missing.
  final String title;
  final String body;
  final Map<String, dynamic> data;

  String? _str(String key) {
    final s = data[key]?.toString().trim();
    return s == null || s.isEmpty || s == 'null' ? null : s;
  }

  int? _int(String key) {
    final v = data[key];
    return v is num
        ? v.toInt()
        : v is String
        ? int.tryParse(v)
        : null;
  }

  /// Heading in the app language, like the Android notification.
  String get localizedTitle {
    final child = childName;
    switch (kind) {
      case 'message':
        return _str('sender') ?? (title.isEmpty ? 'NIGOH Family' : title);
      case 'sos':
        return child == null ? 'SOS' : 'SOS — $child';
      case 'time_request':
        final app = _str('app_name');
        final minutes = _int('minutes') ?? 0;
        if (child != null && app != null && minutes > 0) {
          return tr('{name}: +{minutes} дақ барои {app}', {
            'name': child,
            'minutes': minutes,
            'app': app,
          });
        }
      case 'low_battery':
        final battery = _int('battery');
        if (child != null && battery != null) {
          return tr('{name}: батарея {battery}%', {
            'name': child,
            'battery': battery,
          });
        }
      case 'offline':
        if (child != null) return tr('{name} офлайн аст', {'name': child});
      case 'new_app':
        if (child != null) {
          return tr('{name} барномаи нав насб кард', {'name': child});
        }
      case 'missed_call':
        return tr('Занги ҷавобнадода');
    }
    return title.isEmpty ? 'NIGOH Family' : title;
  }

  /// Text under the heading. User content (chat text, SOS text, reasons,
  /// app names) is shown as is.
  String get localizedBody {
    final child = childName;
    switch (kind) {
      case 'sos':
        return _str('content') ??
            (body.isNotEmpty
                ? body
                : child == null
                ? tr('Фарзанд ёрӣ мехоҳад. Ҷойгиршавиро бинед.')
                : tr('{name} ёрӣ мехоҳад. Ҷойгиршавиро бинед.', {
                    'name': child,
                  }));
      case 'time_request':
        if (_str('app_name') != null) {
          return _str('reason') ?? tr('Фарзанд вақти иловагӣ мепурсад.');
        }
      case 'low_battery':
        if (data.containsKey('battery')) {
          return tr('Телефони фарзанд ба зудӣ хомӯш мешавад.');
        }
      case 'offline':
        if (child != null) {
          return tr(
            'Телефони фарзанд 20 дақиқа боз ба интернет пайваст нашудааст.',
          );
        }
      case 'new_app':
        final apps = data['apps'];
        if (apps is List && apps.isNotEmpty) {
          final names = apps.map((a) => '$a').where((a) => a.isNotEmpty);
          return names.take(3).join(', ') + (names.length > 3 ? '…' : '');
        }
      case 'missed_call':
        return child ?? body;
    }
    return body;
  }
}

/// Dart long-poll of `/api/mobile/v3/events` for the desktop app (the native
/// Android NotifyService does this on phones). Runs while the app is open.
class DesktopEventLoop {
  DesktopEventLoop(
    this.api, {
    required this.onEvent,
    this.wait = 25,
    this.gap = const Duration(milliseconds: 400),
    this.retryDelay = const Duration(seconds: 5),
  });

  final NigohApi api;
  final void Function(DesktopEvent event) onEvent;

  /// Long-poll seconds per request (server maximum 25).
  final int wait;

  /// Pause between requests, so a server that answers at once is not hammered.
  final Duration gap;

  /// Pause after a failed request.
  final Duration retryDelay;

  /// Last error text (null when the last request worked).
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  int _generation = 0;
  bool _running = false;
  int? _afterId;
  Timer? _timer;
  Completer<void>? _sleeper;

  bool get running => _running;

  void start() {
    if (_running) return;
    _running = true;
    _run(++_generation);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
    final sleeper = _sleeper;
    _sleeper = null;
    if (sleeper != null && !sleeper.isCompleted) sleeper.complete();
  }

  Future<void> _sleep(Duration duration) {
    final completer = Completer<void>();
    _sleeper = completer;
    _timer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _run(int generation) async {
    while (generation == _generation) {
      final after = _afterId;
      try {
        final result = await api.events(
          afterId: after ?? 0,
          wait: after == null ? 0 : wait,
        );
        if (generation != _generation) return;
        var latest = (result['latest_id'] as num?)?.toInt() ?? after ?? 0;
        final raw = result['events'];
        if (raw is List) {
          for (final item in raw) {
            final event = DesktopEvent.fromJson(item);
            if (event == null) continue;
            latest = math.max(latest, event.id);
            // after_id 0 only fixes the position: no backlog on start.
            if (after != null && event.id > after) {
              try {
                onEvent(event);
              } catch (e) {
                lastError.value = '$e';
              }
            }
          }
        }
        _afterId = math.max(latest, after ?? 0);
        if (lastError.value != null) lastError.value = null;
        await _sleep(gap);
      } catch (e) {
        if (generation != _generation) return;
        lastError.value = e is ApiException
            ? e.message
            : tr('Огоҳиномаҳо гирифта нашуданд. Интернетро санҷед.');
        await _sleep(retryDelay);
      }
    }
  }
}

/// Shows desktop events inside the app: a banner (snackbar) for family
/// events, a loud red dialog for SOS and the call screen for calls.
class DesktopAlerts {
  DesktopAlerts(
    this.navigatorKey, {
    this.soundInterval = const Duration(seconds: 2),
  });

  final GlobalKey<NavigatorState> navigatorKey;

  /// How often the alert sound repeats while an SOS dialog is open.
  final Duration soundInterval;

  bool _sosOpen = false;
  Timer? _siren;

  /// The SOS alarm is ringing (tests).
  bool get sosRinging => _siren != null;

  NigohApi? api;

  void handle(DesktopEvent event) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    switch (event.kind) {
      case 'call':
        _incomingCall(navigator, event);
      case 'call_end':
        break; // The call screen follows the call status itself.
      case 'sos':
        _sos(navigator, event);
      default:
        _banner(navigator, event);
    }
  }

  /// Routes like a tap on an Android notification.
  void _open(NavigatorState navigator, DesktopEvent event) {
    navigator.popUntil((route) => route.isFirst);
    homeTarget.value = HomeTarget.forEvent(event.kind, event.childId);
  }

  Future<void> _incomingCall(
    NavigatorState navigator,
    DesktopEvent event,
  ) async {
    final raw = event.data['call_id'];
    final callId = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (callId == null || CallScreen.isOpen) return;
    final api = this.api;
    if (api != null) {
      // Skip calls that already stopped ringing.
      try {
        final status = (await api.callStatus(callId))['status']?.toString();
        if (status != null && status != 'ringing') return;
      } catch (_) {
        // Unknown: show the call; the call screen reports errors itself.
      }
    }
    if (!navigator.mounted) return;
    final peer = event.data['caller_name']?.toString();
    _beep();
    await CallScreen.openIncoming(
      navigator,
      callId: callId,
      childId: event.childId ?? 0,
      peerName: peer == null || peer.isEmpty || peer == 'null'
          ? (event.childName ?? 'NIGOH Family')
          : peer,
    );
  }

  void _banner(NavigatorState navigator, DesktopEvent event) {
    final messenger = ScaffoldMessenger.maybeOf(navigator.context);
    if (messenger == null) return;
    _beep();
    final width = MediaQuery.maybeSizeOf(navigator.context)?.width ?? 0;
    final icon = switch (event.kind) {
      'message' => Icons.chat_bubble_rounded,
      'time_request' || 'time_decision' => Icons.more_time_rounded,
      'low_battery' => Icons.battery_alert_rounded,
      'offline' => Icons.wifi_off_rounded,
      'new_app' => Icons.apps_rounded,
      'missed_call' => Icons.phone_missed_rounded,
      _ => Icons.notifications_rounded,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: ValueKey('desktop-event-${event.id}'),
          behavior: SnackBarBehavior.floating,
          width: width >= 600 ? 440 : null,
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.localizedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (event.localizedBody.isNotEmpty)
                      Text(
                        event.localizedBody,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: tr('Дидан'),
            onPressed: () {
              final nav = navigatorKey.currentState;
              if (nav != null) _open(nav, event);
            },
          ),
        ),
      );
  }

  Future<void> _sos(NavigatorState navigator, DesktopEvent event) async {
    if (_sosOpen) return;
    _sosOpen = true;
    _startSiren();
    try {
      await showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (dialogContext) => SosAlertDialog(
          title: event.localizedTitle,
          text: event.localizedBody,
          onSilence: () => Navigator.pop(dialogContext),
        ),
      );
    } finally {
      stopSiren();
      _sosOpen = false;
    }
    final nav = navigatorKey.currentState;
    if (nav != null) _open(nav, event);
  }

  void _startSiren() {
    _siren?.cancel();
    _beep();
    _siren = Timer.periodic(soundInterval, (_) => _beep());
  }

  void stopSiren() {
    _siren?.cancel();
    _siren = null;
  }
}

/// System alert sound (Windows: MessageBeep). Never throws.
void _beep() {
  SystemSound.play(SystemSoundType.alert).catchError((Object _) {});
}

/// Full-attention SOS alert for the desktop app.
class SosAlertDialog extends StatelessWidget {
  const SosAlertDialog({
    super.key,
    required this.title,
    required this.text,
    required this.onSilence,
  });

  final String title;
  final String text;
  final VoidCallback onSilence;

  static const red = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('desktop-sos'),
    backgroundColor: red,
    iconColor: Colors.white,
    icon: const Icon(Icons.sos_rounded, size: 56),
    title: Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
    ),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4),
      ),
    ),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      FilledButton.icon(
        key: const ValueKey('desktop-sos-silence'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: red,
          minimumSize: const Size(200, 50),
        ),
        onPressed: onSilence,
        icon: const Icon(Icons.volume_off_rounded),
        label: Text(tr('Хомӯш кардан')),
      ),
    ],
  );
}

/// The running desktop loop (one per signed-in parent); see main.dart.
abstract final class DesktopNotifications {
  static DesktopEventLoop? _loop;
  static DesktopAlerts? _alerts;
  static String? _token;

  /// True while the loop runs; Settings shows the status.
  static final ValueNotifier<bool> active = ValueNotifier(false);

  /// Last error of the running loop.
  static final ValueNotifier<String?> lastError = ValueNotifier(null);

  static void start(NigohApi api, GlobalKey<NavigatorState> navigatorKey) {
    if (_loop != null && _token == api.token) return;
    stop();
    _token = api.token;
    final alerts = DesktopAlerts(navigatorKey)..api = api;
    final loop = DesktopEventLoop(api, onEvent: alerts.handle);
    loop.lastError.addListener(() => lastError.value = loop.lastError.value);
    _alerts = alerts;
    _loop = loop..start();
    active.value = true;
  }

  static void stop() {
    _loop?.stop();
    _alerts?.stopSiren();
    _loop = null;
    _alerts = null;
    _token = null;
    active.value = false;
    lastError.value = null;
  }
}
