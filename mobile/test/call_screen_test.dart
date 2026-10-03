import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/features/call/call_controller.dart';
import 'package:nigoh_family_parent/features/call/call_screen.dart';
import 'package:nigoh_family_parent/features/call/rtc_engine.dart';

import 'call_fakes.dart';

void main() {
  late FakeCallServer server;
  late FakeRtcEngine engine;

  CallController controller() => CallController(
    api: NigohApi(client: server.client, baseUrl: 'http://t'),
    engine: engine,
    micPermission: () async => true,
    pollWait: 0,
    pollIdle: const Duration(milliseconds: 200),
  );

  Future<void> pumpScreen(WidgetTester tester, CallController c) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: CallScreen(controller: c, peerName: 'Алӣ'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  }

  setUp(() {
    server = FakeCallServer();
    engine = FakeRtcEngine();
  });

  testWidgets('incoming call shows name, status, accept and decline', (
    tester,
  ) async {
    final c = controller()..startIncoming(5);
    await pumpScreen(tester, c);
    expect(find.text('Алӣ'), findsOneWidget);
    expect(find.text('А'), findsOneWidget);
    expect(find.text('Занги даромада'), findsOneWidget);
    expect(find.text('Қабул'), findsOneWidget);
    expect(find.text('Рад'), findsOneWidget);
    expect(find.text('Хотима'), findsNothing);
    // The state line is followed by a hint telling the child what to do.
    expect(
      find.text('«Қабул» — ҷавоб додан, «Рад» — рад кардан'),
      findsOneWidget,
    );
    expect(find.byTooltip('Қабул'), findsOneWidget);
    expect(find.byTooltip('Рад'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Рад шуд'), findsOneWidget);
    expect(server.posted('/5/decline'), isTrue);
    expect(engine.closed, isTrue);
    await unmount(tester);
  });

  testWidgets('outgoing call shows speaker, mute and end buttons', (
    tester,
  ) async {
    final c = controller();
    await pumpScreen(tester, c);
    c.startOutgoing(7);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Алӣ'), findsOneWidget);
    expect(find.text('Занг задан…'), findsOneWidget);
    expect(find.text('Динамик'), findsOneWidget);
    expect(find.text('Микрофон'), findsOneWidget);
    expect(find.text('Хотима'), findsOneWidget);
    expect(find.text('Қабул'), findsNothing);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    expect(c.muted, isTrue);
    expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Занг тамом шуд'), findsOneWidget);
    expect(server.posted('/5/end'), isTrue);
    await unmount(tester);
  });

  testWidgets('active call shows a running mm:ss timer', (tester) async {
    final c = controller()..startIncoming(5);
    server.deliver('offer', {'sdp': 'o', 'type': 'offer'});
    await pumpScreen(tester, c);
    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Пайвастшавӣ…'), findsOneWidget);
    engine.emitLink(RtcLinkState.connected);
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Барои хотима «Хотима»-ро пахш кунед'), findsOneWidget);
    await unmount(tester);
  });

  test('duration format', () {
    expect(formatCallDuration(const Duration(seconds: 65)), '01:05');
    expect(formatCallDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
  });
}
