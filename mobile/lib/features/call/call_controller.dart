import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api.dart';
import 'rtc_engine.dart';

enum CallState { idle, outgoing, incoming, connecting, active, ended }

/// Why a call ended — [label] is shown on the call screen.
enum CallEndReason {
  hangup('Занг тамом шуд'),
  remoteEnded('Занг тамом шуд'),
  declined('Рад шуд'),
  noAnswer('Ҷавоб надод'),
  connectFailed('Пайвастшавӣ нашуд'),
  micDenied('Иҷозати микрофон дода нашуд'),
  error('Хатогӣ');

  const CallEndReason(this.label);
  final String label;
}

Future<bool> requestMicrophonePermission() async =>
    (await Permission.microphone.request()).isGranted;

/// One audio call (outgoing or incoming) between a parent and a child phone.
///
/// Signaling goes through the NIGOH server: the caller creates the call,
/// sends an SDP offer right away and both sides long-poll
/// `/calls/{id}/signals`, which also returns the call status.
class CallController extends ChangeNotifier {
  CallController({
    required this.api,
    RtcEngine? engine,
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
  CallState get state => _state;

  CallEndReason? _endReason;
  CallEndReason? get endReason => _endReason;

  /// Text for the end status (server/network message for [CallEndReason.error]).
  String? get endMessage => _endReason == CallEndReason.error
      ? (lastError ?? _endReason!.label)
      : _endReason?.label;

  /// Last error from the server or WebRTC (kept for a visible status).
  String? lastError;

  int? _callId;
  int? get callId => _callId;
  bool _isCaller = false;
  bool get isCaller => _isCaller;

  bool _muted = false;
  bool get muted => _muted;
  bool _speaker = false;
  bool get speaker => _speaker;

  DateTime? _activeSince;
  Duration get duration => _activeSince == null
      ? Duration.zero
      : DateTime.now().difference(_activeSince!);

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

  // ---------- Outgoing ----------

  /// Calls the child (or parent, from the child phone) for [childId].
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

  // ---------- Incoming ----------

  /// Starts watching an incoming call (ringing on this phone).
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

  /// Accepts the incoming call: mic → /accept → answer the offer.
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

  /// Declines the incoming call.
  Future<void> decline() => _end(CallEndReason.declined);

  /// Hangs up (or cancels/declines while ringing).
  Future<void> hangUp() => _end(
    _state == CallState.incoming
        ? CallEndReason.declined
        : CallEndReason.hangup,
  );

  // ---------- Controls ----------

  void toggleMute() {
    _muted = !_muted;
    if (_engineOpen) engine.setMuted(_muted);
    _notify();
  }

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

  // ---------- Internals ----------

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

  void _becomeActive() {
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _activeSince = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    _setState(CallState.active);
  }

  void _startConnectTimer() {
    _connectTimer?.cancel();
    _connectTimer = Timer(connectTimeout, () {
      if (_state == CallState.connecting) _end(CallEndReason.connectFailed);
    });
  }

  void _enterConnecting() {
    if (_state != CallState.outgoing) return;
    _ringTimer?.cancel();
    _setState(CallState.connecting);
    _startConnectTimer();
  }

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

  Future<void> _answer(Map<String, dynamic> offer) async {
    await engine.setRemote(offer);
    _remoteSet = true;
    await _flushCandidates();
    if (ended) return;
    final answer = await engine.createAnswer();
    if (ended) return;
    await _send('answer', jsonEncode(answer));
  }

  Future<void> _flushCandidates() async {
    final queued = List.of(_pendingCandidates);
    _pendingCandidates.clear();
    for (final c in queued) {
      await _addCandidate(c);
    }
  }

  Future<void> _addCandidate(Map<String, dynamic> c) async {
    try {
      await engine.addCandidate(c);
    } catch (e) {
      // One bad candidate must not kill the call; others may still work.
      lastError = '$e';
    }
  }

  void _startPolling() {
    if (_polling) return;
    _polling = true;
    unawaited(_pollLoop());
  }

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

  Future<void> _handleSignal(Map<String, dynamic> s) async {
    final kind = s['kind'];
    final payload = s['payload'];
    Map<String, dynamic> data;
    try {
      final decoded = payload is String ? jsonDecode(payload) : payload;
      data = Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      lastError = 'Сигнали нодуруст';
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

  Future<void> _sleep(Duration d) {
    final c = Completer<void>();
    _sleeper = c;
    _sleepTimer = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

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

  void _setState(CallState s) {
    _state = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

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
