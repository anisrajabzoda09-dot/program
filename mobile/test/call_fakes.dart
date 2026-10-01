import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/features/call/rtc_engine.dart';

/// In-memory WebRTC stand-in: records what the controller asked for.
class FakeRtcEngine implements RtcEngine {
  @override
  void Function(Map<String, dynamic> candidate)? onIceCandidate;
  @override
  void Function(RtcLinkState state)? onLinkState;

  bool opened = false;
  bool closed = false;
  bool muted = false;
  bool speaker = false;
  List<Map<String, dynamic>>? iceServers;
  Map<String, dynamic>? remote;
  final List<Map<String, dynamic>> candidates = [];

  /// Candidates added while no remote description was set (must stay empty).
  int candidatesBeforeRemote = 0;

  @override
  Future<void> open(List<Map<String, dynamic>> iceServers) async {
    this.iceServers = iceServers;
    opened = true;
  }

  @override
  Future<Map<String, dynamic>> createOffer() async => {
    'sdp': 'v=0 offer',
    'type': 'offer',
  };

  @override
  Future<Map<String, dynamic>> createAnswer() async => {
    'sdp': 'v=0 answer',
    'type': 'answer',
  };

  @override
  Future<void> setRemote(Map<String, dynamic> description) async =>
      remote = description;

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async {
    if (remote == null) candidatesBeforeRemote++;
    candidates.add(candidate);
  }

  @override
  void setMuted(bool muted) => this.muted = muted;

  @override
  Future<void> setSpeaker(bool on) async => speaker = on;

  @override
  Future<void> close() async => closed = true;

  void emitIce(String c) =>
      onIceCandidate?.call({'candidate': c, 'sdpMid': '0', 'sdpMLineIndex': 0});

  void emitLink(RtcLinkState s) => onLinkState?.call(s);
}

/// Minimal fake of the NIGOH call signaling API (call id 5).
class FakeCallServer {
  String status = 'ringing';
  final List<Map<String, dynamic>> inbox = [];
  final List<String> log = [];
  final List<Map<String, dynamic>> sent = [];
  Map<String, dynamic>? startBody;

  /// When set, POST /calls fails with HTTP 409 and this detail.
  String? startError;
  int _nextId = 1;

  void deliver(String kind, Object payload) => inbox.add({
    'id': _nextId++,
    'from_role': 'other',
    'kind': kind,
    'payload': jsonEncode(payload),
  });

  bool posted(String suffix) => log.contains('POST $suffix');

  static http.Response _json(Object body, [int code = 200]) => http.Response(
    jsonEncode(body),
    code,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// Returns null for paths it does not know.
  Future<http.Response?> handle(http.Request req) async {
    final path = req.url.path;
    if (!path.startsWith('/api/mobile/v3/calls')) return null;
    final rel = path.substring('/api/mobile/v3/calls'.length);
    log.add('${req.method} ${rel.isEmpty ? '/' : rel}');
    if (rel == '/config') {
      return _json({
        'ice_servers': [
          {
            'urls': ['stun:stun.example.org:3478'],
          },
        ],
      });
    }
    if (rel.isEmpty && req.method == 'POST') {
      startBody = jsonDecode(req.body) as Map<String, dynamic>;
      if (startError != null) return _json({'detail': startError}, 409);
      return _json({
        'call': {'id': 5, 'status': 'ringing', 'caller_role': 'parent'},
      });
    }
    if (rel == '/5/accept') status = 'active';
    if (rel == '/5/decline') status = 'declined';
    if (rel == '/5/end') status = 'ended';
    if (rel == '/5/signal') {
      sent.add(jsonDecode(req.body) as Map<String, dynamic>);
    }
    if (rel == '/5/signals') {
      final after = int.parse(req.url.queryParameters['after_id'] ?? '0');
      return _json({
        'call': {'id': 5, 'status': status},
        'signals': inbox.where((s) => (s['id'] as int) > after).toList(),
      });
    }
    return _json({
      'status': 'success',
      'call': {'id': 5, 'status': status},
    });
  }

  MockClient get client => MockClient(
    (req) async => await handle(req) ?? _json({'detail': 'not found'}, 404),
  );
}
