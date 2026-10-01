import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/features/child/child_home.dart';
import 'package:nigoh_family_parent/features/child/child_sync.dart';
import 'package:nigoh_family_parent/features/child/child_widgets.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> serverChild({bool bedtime = false, int unread = 0}) => {
  'id': 5,
  'name': 'Алӣ',
  'pairing_code': '482913',
  'is_paired': true,
  'parent_name': 'Модар',
  'unread_from_parent': unread,
  'bedtime': {'enabled': bedtime, 'start': '21:30', 'end': '07:00'},
  'location': {
    'latitude': 38.5598,
    'longitude': 68.787,
    'updated_at': '2026-10-01 18:00:00',
  },
  'apps': [
    {
      'package_name': 'com.video',
      'app_name': 'Video',
      'usage_minutes_today': 70,
    },
    {
      'package_name': 'com.game',
      'app_name': 'Game',
      'usage_minutes_today': 25,
    },
    {'package_name': 'com.idle', 'app_name': 'Idle', 'usage_minutes_today': 0},
  ],
};

void main() {
  const channel = MethodChannel('tj.nigoh/device_control');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getProtectionStatus':
              return {
                'usage': true,
                'overlay': true,
                'accessibility': true,
                'location': true,
                'notifications': true,
              };
            case 'getInstalledApps':
              return [
                {'packageName': 'com.video', 'appName': 'Video'},
              ];
            case 'getBatteryLevel':
              return 42;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('SOS text has the map link and battery', () {
    final text = sosMessageText(latitude: 38.5, longitude: 68.75, battery: 9);
    expect(text, contains('SOS — ба кӯмак ниёз дорам'));
    expect(text, contains('https://maps.google.com/?q=38.500000,68.750000'));
    expect(text, contains('Батарея: 9%'));
    expect(sosMessageText(), isNot(contains('maps.google.com')));
  });

  Future<(ChildSync, List<Map<String, dynamic>>)> pump(
    WidgetTester tester, {
    Map<String, dynamic>? child,
    DateTime? now,
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final chats = <Map<String, dynamic>>[];
    final sync = ChildSync(
      api: NigohApi(
        client: MockClient((req) async {
          if (req.url.path == '/api/mobile/v2/snapshot') {
            return json({'child': child ?? serverChild()});
          }
          if (req.url.path == '/api/mobile/v2/children/5/chat' &&
              req.method == 'POST') {
            chats.add(jsonDecode(req.body) as Map<String, dynamic>);
            return json({'status': 'success'});
          }
          return json({'status': 'success'});
        }),
        baseUrl: 'http://t',
      ),
      trackLocation: false,
      listenPackageEvents: false,
      clock: () => now ?? DateTime(2026, 10, 1, 12),
    );
    await tester.pumpWidget(MaterialApp(home: ChildHome(sync: sync)));
    await tester.pumpAndSettle();
    return (sync, chats);
  }

  Future<void> finish(WidgetTester tester, ChildSync sync) async {
    await tester.pumpWidget(const SizedBox());
    sync.dispose();
  }

  testWidgets('SOS is sent only after a 1.5 s hold', (tester) async {
    final (sync, chats) = await pump(tester);
    final sos = find.text('SOS');
    expect(sos, findsOneWidget);

    // A short press does nothing.
    var gesture = await tester.startGesture(tester.getCenter(sos));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(chats, isEmpty);

    gesture = await tester.startGesture(tester.getCenter(sos));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(chats, hasLength(1));
    expect(chats.single['message_type'], 'urgent');
    final text = chats.single['content'] as String;
    expect(text, contains('SOS — ба кӯмак ниёз дорам'));
    expect(text, contains('https://maps.google.com/?q=38.559800,68.787000'));
    expect(text, contains('Батарея: 42%'));
    expect(find.textContaining('SOS фиристода шуд'), findsOneWidget);
    await finish(tester, sync);
  });

  testWidgets('screen time shows the total and top apps', (tester) async {
    final (sync, _) = await pump(tester);
    expect(find.text('Вақти экрани ман'), findsOneWidget);
    expect(find.text('1 соат 35 дақ'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('1 соат 10 дақ'), findsOneWidget);
    expect(find.text('25 дақ'), findsOneWidget);
    expect(find.text('Idle'), findsNothing);
    await finish(tester, sync);
  });

  testWidgets('bedtime notice while bedtime is active', (tester) async {
    final (sync, _) = await pump(
      tester,
      child: serverChild(bedtime: true),
      now: DateTime(2026, 10, 1, 22, 15),
    );
    expect(
      find.text('Вақти хоб — барномаҳо то 07:00 баста ҳастанд'),
      findsOneWidget,
    );
    await finish(tester, sync);
  });

  testWidgets('no bedtime notice outside the window', (tester) async {
    final (sync, _) = await pump(tester, child: serverChild(bedtime: true));
    expect(find.textContaining('Вақти хоб —'), findsNothing);
    await finish(tester, sync);
  });

  testWidgets('chat tab shows the unread badge', (tester) async {
    final (sync, _) = await pump(tester, child: serverChild(unread: 3));
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('3')),
      findsOneWidget,
    );
    expect(find.text('Қоидаҳо'), findsOneWidget);
    await finish(tester, sync);
  });
}
