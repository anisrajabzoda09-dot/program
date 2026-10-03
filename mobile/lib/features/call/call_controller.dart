// Файл: ҳолат ва signaling-и занги WebRTC.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api.dart';
import 'rtc_engine.dart';
import '../../l10n/l10n.dart';

/// Ҳолатҳо ё навъҳои имконпазири ҳолат ва signaling-и занги WebRTC-ро муайян мекунад.
enum CallState { idle, outgoing, incoming, connecting, active, ended }

/// Ҳолатҳо ё навъҳои имконпазири ҳолат ва signaling-и занги WebRTC-ро муайян мекунад.
enum CallEndReason {
  hangup('Занг тамом шуд'),
  remoteEnded('Занг тамом шуд'),
  declined('Рад шуд'),
  noAnswer('Ҷавоб надод'),
  connectFailed('Пайвастшавӣ нашуд'),
  micDenied('Иҷозати микрофон дода нашуд'),
  error('Хатогӣ');

  const CallEndReason(this._label);
  final String _label;

  /// Қимати ҳисобшудаи label-ро аз ҳолати ҷорӣ бармегардонад.
  String get label => tr(_label);
}

/// requestMicrophonePermission иҷозат ё маълумоти лозимро дархост мекунад.
Future<bool> requestMicrophonePermission() async {
  return (await Permission.microphone.request()).isGranted;
}

/// Мантиқ ва ҳолати ҳолат ва signaling-и занги WebRTC-ро идора мекунад.
class CallController extends ChangeNotifier {
  CallController({
    required this.api,
    RtcEngine? engine,
    /// Function мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
    Future<bool> Function()? micPermission,
    this.ringTimeout = const Duration(seconds: 45),
    this.incomingTimeout = const Duration(seconds: 60),
    this.connectTimeout = const Duration(seconds: 20),
    this.pollWait = 10,
    this.pollIdle = const Duration(milliseconds: 300),
  }) : engine = engine ?? FlutterRtcEngine(),
       _micPermission = micPermission ?? requestMicrophonePermission;

  final NigohApi api;
  final RtcEngine engine;
  final Future<bool> Function() _micPermission;
  final Duration ringTimeout;
  final Duration incomingTimeout;
  final Duration connectTimeout;
  final int pollWait;
  final Duration pollIdle;

  CallState _state = CallState.idle;
  /// Қимати ҳисобшудаи state-ро аз ҳолати ҷорӣ бармегардонад.
  CallState get state => _state;

  CallEndReason? _endReason;
  /// Қимати ҳисобшудаи endReason-ро аз ҳолати ҷорӣ бармегардонад.
  CallEndReason? get endReason => _endReason;

  /// Қимати endMessage-ро барои ҳолат ва signaling-и занги WebRTC нигоҳ медорад.
  String? get endMessage => _endReason == CallEndReason.error
      ? (lastError ?? _endReason!.label)
      : _endReason?.label;

  /// Қимати lastError-ро барои ҳолат ва signaling-и занги WebRTC нигоҳ медорад.
  String? lastError;

  int? _callId;
  /// Қимати ҳисобшудаи callId-ро аз ҳолати ҷорӣ бармегардонад.
  int? get callId => _callId;
  bool _isCaller = false;
  /// Қимати ҳисобшудаи isCaller-ро аз ҳолати ҷорӣ бармегардонад.
  bool get isCaller => _isCaller;

  bool _muted = false;
  /// Қимати ҳисобшудаи muted-ро аз ҳолати ҷорӣ бармегардонад.
  bool get muted => _muted;
  bool _speaker = false;
  /// Қимати ҳисобшудаи speaker-ро аз ҳолати ҷорӣ бармегардонад.
  bool get speaker => _speaker;

  DateTime? _activeSince;

  /// Қимати duration-ро барои ҳолат ва signaling-и занги WebRTC нигоҳ медорад.
  Duration get duration => _activeSince == null
      ? Duration.zero
      : DateTime.now().difference(_activeSince!);

  /// Қимати ҳисобшудаи ended-ро аз ҳолати ҷорӣ бармегардонад.
  bool get ended => _state == CallState.ended;

  bool _accepted = false;
  bool _engineOpen = false;
  bool _remoteSet = false;
  Map<String, dynamic>? _pendingOffer;
  final List<Map<String, dynamic>> _pendingCandidates = [];
  int _lastSignalId = 0;
  bool _polling = false;
  bool _disposed = false;

  Timer? _ringTimer;
  Timer? _connectTimer;
  Timer? _tick;
  Timer? _sleepTimer;
  Completer<void>? _sleeper;
  Future<void> _sendChain = Future.value();

  // Қадами дохилии startOutgoing барои идораи занг.

  /// startOutgoing раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  Future<void> startOutgoing(int childId) async {
    if (_state != CallState.idle) return;
    _isCaller = true;
    _setState(CallState.outgoing);
    try {
      if (!await _micPermission()) {
        await _end(CallEndReason.micDenied, notifyServer: false);
        return;
      }
      if (ended) return;
      final ice = await api.callConfig();
      if (ended) return;
      final call = await api.startCall(childId);
      _callId = (call['id'] as num).toInt();
      if (ended) {
        await _notifyServerEnd(wasRinging: false);
        return;
      }
      _ringTimer = Timer(ringTimeout, () {
        if (_state == CallState.outgoing) _end(CallEndReason.noAnswer);
      });
      await _openEngine(ice);
      if (ended) return;
      final offer = await engine.createOffer();
      if (ended) return;
      await _send('offer', jsonEncode(offer));
      _startPolling();
    } catch (e) {
      lastError = '$e';
      await _end(CallEndReason.error);
    }
  }

  // Қадами дохилии startIncoming барои идораи занг.

  /// startIncoming раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void startIncoming(int callId) {
    if (_state != CallState.idle) return;
    _callId = callId;
    _isCaller = false;
    _setState(CallState.incoming);
    _ringTimer = Timer(incomingTimeout, () {
      if (_state == CallState.incoming) {
        _end(CallEndReason.noAnswer, notifyServer: false);
      }
    });
    _startPolling();
  }

  /// accept мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
  Future<void> accept() async {
    if (_state != CallState.incoming || _accepted) return;
    _accepted = true;
    _ringTimer?.cancel();
    _setState(CallState.connecting);
    try {
      if (!await _micPermission()) {
        await _end(CallEndReason.micDenied, declineIfRinging: true);
        return;
      }
      if (ended) return;
      final ice = await api.callConfig();
      if (ended) return;
      await api.acceptCall(_callId!);
      if (ended) return;
      _startConnectTimer();
      await _openEngine(ice);
      if (ended) return;
      final offer = _pendingOffer;
      _pendingOffer = null;
      if (offer != null) await _answer(offer);
    } catch (e) {
      lastError = '$e';
      await _end(CallEndReason.error);
    }
  }

  /// decline раванди фаъолро қатъ карда, захираҳои онро озод мекунад.
  Future<void> decline() => _end(CallEndReason.declined);

  /// hangUp раванди фаъолро қатъ карда, захираҳои онро озод мекунад.
  Future<void> hangUp() => _end(
    _state == CallState.incoming
        ? CallEndReason.declined
        : CallEndReason.hangup,
  );

  // Қадами дохилии toggleMute барои идораи занг.

  /// toggleMute ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  void toggleMute() {
    _muted = !_muted;
    if (_engineOpen) engine.setMuted(_muted);
    _notify();
  }

  /// toggleSpeaker ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> toggleSpeaker() async {
    _speaker = !_speaker;
    _notify();
    if (!_engineOpen) return;
    try {
      await engine.setSpeaker(_speaker);
    } catch (e) {
      lastError = '$e';
      _speaker = !_speaker;
      _notify();
    }
  }

  // Қадами дохилии openEngine барои идораи занг.

  /// openEngine экран, dialog ё танзимоти мувофиқро мекушояд.
  Future<void> _openEngine(List<Map<String, dynamic>> ice) async {
    engine.onIceCandidate = (c) {
      if (!ended) _send('ice', jsonEncode(c));
    };
    engine.onLinkState = _onLink;
    await engine.open(ice);
    if (ended) return;
    _engineOpen = true;
    if (_muted) engine.setMuted(true);
    if (_speaker) await engine.setSpeaker(true);
  }

  /// onLink рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void _onLink(RtcLinkState link) {
    if (ended) return;
    switch (link) {
      case RtcLinkState.connected:
        if (_state == CallState.connecting ||
            (_state == CallState.outgoing && _remoteSet)) {
          _becomeActive();
        }
      case RtcLinkState.failed:
        _end(CallEndReason.connectFailed);
      case RtcLinkState.connecting:
      case RtcLinkState.disconnected:
        break;
    }
  }

  /// becomeActive мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
  void _becomeActive() {
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _activeSince = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    _setState(CallState.active);
  }

  /// startConnectTimer раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void _startConnectTimer() {
    _connectTimer?.cancel();
    _connectTimer = Timer(connectTimeout, () {
      if (_state == CallState.connecting) _end(CallEndReason.connectFailed);
    });
  }

  /// enterConnecting мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
  void _enterConnecting() {
    if (_state != CallState.outgoing) return;
    _ringTimer?.cancel();
    _setState(CallState.connecting);
    _startConnectTimer();
  }

  /// send дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> _send(String kind, String payload) {
    final id = _callId;
    if (id == null) return Future.value();
    final next = _sendChain.then((_) async {
      if (ended) return;
      try {
        await api.sendSignal(id, kind, payload);
      } catch (e) {
        lastError = '$e';
        if (kind != 'ice') rethrow;
      }
    });
    _sendChain = next.catchError((_) {});
    return next;
  }

  /// answer мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
  Future<void> _answer(Map<String, dynamic> offer) async {
    await engine.setRemote(offer);
    _remoteSet = true;
    await _flushCandidates();
    if (ended) return;
    final answer = await engine.createAnswer();
    if (ended) return;
    await _send('answer', jsonEncode(answer));
  }

  /// flushCandidates мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
  Future<void> _flushCandidates() async {
    final queued = List.of(_pendingCandidates);
    _pendingCandidates.clear();
    for (final c in queued) {
      await _addCandidate(c);
    }
  }

  /// addCandidate мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
  Future<void> _addCandidate(Map<String, dynamic> c) async {
    try {
      await engine.addCandidate(c);
    } catch (e) {
      // Қадами дохилии startPolling барои идораи занг.
      lastError = '$e';
    }
  }

  /// startPolling раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void _startPolling() {
    if (_polling) return;
    _polling = true;
    unawaited(_pollLoop());
  }

  /// pollLoop мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
  Future<void> _pollLoop() async {
    var failures = 0;
    while (!ended) {
      try {
        final r = await api.callSignals(
          _callId!,
          afterId: _lastSignalId,
          wait: pollWait,
        );
        if (ended) return;
        failures = 0;
        final signals = (r['signals'] as List?) ?? const [];
        for (final raw in signals) {
          if (raw is! Map) continue;
          final s = Map<String, dynamic>.from(raw);
          final id = (s['id'] as num?)?.toInt() ?? 0;
          if (id <= _lastSignalId) continue;
          _lastSignalId = id;
          await _handleSignal(s);
          if (ended) return;
        }
        final call = r['call'];
        if (call is Map) _handleStatus('${call['status']}');
        if (ended) return;
        if (signals.isEmpty) await _sleep(pollIdle);
      } catch (e) {
        if (ended) return;
        lastError = '$e';
        failures++;
        _notify();
        await _sleep(Duration(seconds: math.min(failures, 5)));
      }
    }
  }

  /// handleSignal рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  Future<void> _handleSignal(Map<String, dynamic> s) async {
    final kind = s['kind'];
    final payload = s['payload'];
    Map<String, dynamic> data;
    try {
      final decoded = payload is String ? jsonDecode(payload) : payload;
      data = Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      lastError = tr('Сигнали нодуруст');
      return;
    }
    try {
      switch (kind) {
        case 'offer':
          if (_isCaller) return;
          if (_accepted && _engineOpen) {
            await _answer(data);
          } else {
            _pendingOffer = data;
          }
        case 'answer':
          if (!_isCaller || _remoteSet) return;
          await engine.setRemote(data);
          _remoteSet = true;
          _enterConnecting();
          await _flushCandidates();
        case 'ice':
          if (_remoteSet) {
            await _addCandidate(data);
          } else {
            _pendingCandidates.add(data);
          }
      }
    } catch (e) {
      lastError = '$e';
      await _end(CallEndReason.connectFailed);
    }
  }

  /// handleStatus рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void _handleStatus(String status) {
    switch (status) {
      case 'active':
        _enterConnecting();
      case 'declined':
        _end(CallEndReason.declined, notifyServer: false);
      case 'missed':
        _end(CallEndReason.noAnswer, notifyServer: false);
      case 'ended':
        _end(CallEndReason.remoteEnded, notifyServer: false);
    }
  }

  /// sleep мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад.
  Future<void> _sleep(Duration d) {
    final c = Completer<void>();
    _sleeper = c;
    _sleepTimer = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  /// end раванди фаъолро қатъ карда, захираҳои онро озод мекунад.
  Future<void> _end(
    CallEndReason reason, {
    bool notifyServer = true,
    bool declineIfRinging = false,
  }) async {
    if (ended) return;
    final wasIncomingRinging =
        _state == CallState.incoming || (declineIfRinging && !_isCaller);
    _endReason = reason;
    _setState(CallState.ended);
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _tick?.cancel();
    _sleepTimer?.cancel();
    final sleeper = _sleeper;
    if (sleeper != null && !sleeper.isCompleted) sleeper.complete();
    _pendingCandidates.clear();
    _pendingOffer = null;
    try {
      await engine.close();
    } catch (e) {
      lastError = '$e';
    }
    _engineOpen = false;
    if (notifyServer) await _notifyServerEnd(wasRinging: wasIncomingRinging);
  }

  /// notifyServerEnd listener ё корбарро аз тағйирот огоҳ мекунад.
  Future<void> _notifyServerEnd({required bool wasRinging}) async {
    final id = _callId;
    if (id == null) return;
    try {
      if (wasRinging) {
        await api.declineCall(id);
      } else {
        await api.endCall(id);
      }
    } catch (e) {
      lastError = '$e';
      _notify();
    }
  }

  /// setState ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  void _setState(CallState s) {
    _state = s;
    _notify();
  }

  /// notify listener ё корбарро аз тағйирот огоҳ мекунад.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Controller ва listener-ҳои CallController-ро озод мекунад.
  @override
  void dispose() {
    if (!ended) unawaited(hangUp());
    _disposed = true;
    _tick?.cancel();
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _sleepTimer?.cancel();
    super.dispose();
  }
}
