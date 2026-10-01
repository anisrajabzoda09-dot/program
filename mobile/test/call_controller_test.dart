import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/features/call/call_controller.dart';
import 'package:nigoh_family_parent/features/call/rtc_engine.dart';

import 'call_fakes.dart';

Future<void> waitFor(bool Function() condition, [String? what]) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Timed out waiting for ${what ?? 'condition'}');
}

void main() {
  late FakeCallServer server;
  late FakeRtcEngine engine;
  late CallController c;

  CallController make({
    bool mic = true,
    Duration ring = const Duration(seconds: 45),
    Duration connect = const Duration(seconds: 20),
  }) {
    final api = NigohApi(client: server.client, baseUrl: 'http://t')
      ..token = 't'
      ..role = 'parent';
    return c = CallController(
      api: api,
      engine: engine,
      micPermission: () async => mic,
      ringTimeout: ring,
      connectTimeout: connect,
      pollWait: 0,
      pollIdle: const Duration(milliseconds: 5),
    );
  }

  setUp(() {
    server = FakeCallServer();
    engine = FakeRtcEngine();
  });

  tearDown(() async {
    if (!c.ended) await c.hangUp();
    c.dispose();
  });

  test(
    'outgoing: offer is sent right after startCall, answer connects',
    () async {
      make();
      await c.startOutgoing(7);
      expect(server.startBody, {'child_id': 7});
      expect(c.state, CallState.outgoing);
      expect(engine.opened, isTrue);
      expect(engine.iceServers?.first['urls'], ['stun:stun.example.org:3478']);
      final offerIndex = server.log.indexOf('POST /5/signal');
      expect(server.log.indexOf('POST /'), lessThan(offerIndex));
      expect(server.sent.first['kind'], 'offer');
      expect(jsonDecode(server.sent.first['payload'] as String), {
        'sdp': 'v=0 offer',
        'type': 'offer',
      });

      engine.emitIce('cand-a');
      await waitFor(() => server.sent.any((s) => s['kind'] == 'ice'), 'ice');

      server.status = 'active';
      server.deliver('answer', {'sdp': 'v=0 answer', 'type': 'answer'});
      await waitFor(() => c.state == CallState.connecting, 'connecting');
      expect(engine.remote?['type'], 'answer');

      engine.emitLink(RtcLinkState.connected);
      expect(c.state, CallState.active);

      await c.hangUp();
      expect(c.state, CallState.ended);
      expect(c.endReason, CallEndReason.hangup);
      expect(server.posted('/5/end'), isTrue);
      expect(engine.closed, isTrue);
    },
  );

  test(
    'incoming: accept posts /accept, then answers the queued offer',
    () async {
      make();
      server.deliver('offer', {'sdp': 'v=0 offer', 'type': 'offer'});
      server.deliver('ice', {
        'candidate': 'c1',
        'sdpMid': '0',
        'sdpMLineIndex': 0,
      });
      c.startIncoming(5);
      expect(c.state, CallState.incoming);
      await waitFor(
        () =>
            server.log.where((l) => l.startsWith('GET /5/signals')).length >= 2,
      );
      expect(engine.opened, isFalse, reason: 'mic stays closed until accepted');
      expect(engine.candidates, isEmpty);

      await c.accept();
      final acceptAt = server.log.indexOf('POST /5/accept');
      expect(acceptAt, greaterThanOrEqualTo(0));
      expect(server.log.lastIndexOf('POST /5/signal'), greaterThan(acceptAt));
      expect(server.sent.single['kind'], 'answer');
      expect(engine.remote?['type'], 'offer');
      expect(engine.candidates.single['candidate'], 'c1');
      expect(engine.candidatesBeforeRemote, 0);
      expect(c.state, CallState.connecting);

      engine.emitLink(RtcLinkState.connected);
      expect(c.state, CallState.active);
    },
  );

  test('declined status ends with «Рад шуд» and releases the mic', () async {
    make();
    await c.startOutgoing(7);
    server.status = 'declined';
    await waitFor(() => c.ended, 'ended');
    expect(c.endReason, CallEndReason.declined);
    expect(c.endMessage, 'Рад шуд');
    expect(engine.closed, isTrue);
    expect(server.posted('/5/end'), isFalse);
  });

  test('missed status ends with «Ҷавоб надод»', () async {
    make();
    await c.startOutgoing(7);
    server.status = 'missed';
    await waitFor(() => c.ended, 'ended');
    expect(c.endMessage, 'Ҷавоб надод');
  });

  test('callee declining posts /decline', () async {
    make();
    c.startIncoming(5);
    await c.decline();
    expect(c.endMessage, 'Рад шуд');
    expect(server.posted('/5/decline'), isTrue);
  });

  test('ring timeout hangs up with «Ҷавоб надод»', () async {
    make(ring: const Duration(milliseconds: 40));
    await c.startOutgoing(7);
    await waitFor(() => c.ended, 'ended');
    expect(c.endReason, CallEndReason.noAnswer);
    await waitFor(() => server.posted('/5/end'), '/end');
  });

  test('stuck in connecting shows «Пайвастшавӣ нашуд»', () async {
    make(connect: const Duration(milliseconds: 40));
    await c.startOutgoing(7);
    server.status = 'active';
    await waitFor(() => c.ended, 'ended');
    expect(c.endMessage, 'Пайвастшавӣ нашуд');
    await waitFor(() => server.posted('/5/end'), '/end');
    expect(engine.closed, isTrue);
  });

  test('microphone denied: no call is created', () async {
    make(mic: false);
    await c.startOutgoing(7);
    expect(c.endReason, CallEndReason.micDenied);
    expect(server.log, isEmpty);
  });

  test('mute and speaker toggles reach the engine', () async {
    make();
    await c.startOutgoing(7);
    c.toggleMute();
    expect(c.muted, isTrue);
    expect(engine.muted, isTrue);
    c.toggleMute();
    expect(engine.muted, isFalse);
    await c.toggleSpeaker();
    expect(engine.speaker, isTrue);
  });

  test('server error is shown as the end message', () async {
    make();
    server.startError = 'Ҳозир занги дигар идома дорад';
    await c.startOutgoing(7);
    expect(c.endReason, CallEndReason.error);
    expect(c.endMessage, 'Ҳозир занги дигар идома дорад');
    expect(engine.opened, isFalse);
  });
}
