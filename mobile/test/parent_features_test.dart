import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/models.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/apps_screen.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';
import 'package:nigoh_family_parent/features/parent/parent_logic.dart';
import 'package:nigoh_family_parent/features/parent/parent_sheets.dart';
import 'package:nigoh_family_parent/features/parent/requests_screen.dart';
import 'package:nigoh_family_parent/features/parent/weekly_report.dart';

import 'family_controller_test.dart' show snapshotJson, jsonResponse;

String _iso(DateTime t) => t.toUtc().toIso8601String();

Map<String, dynamic> richSnapshot({
  Map<String, dynamic>? lastUrgent,
  int pending = 0,
  int unread = 0,
  Map<String, dynamic>? bedtime,
}) {
  final snap = snapshotJson();
  final child = (snap['children'] as List).first as Map<String, dynamic>;
  child['pending_requests'] = pending;
  child['unread_from_child'] = unread;
  if (lastUrgent != null) child['last_urgent'] = lastUrgent;
  if (bedtime != null) child['bedtime'] = bedtime;
  child['location'] = {
    'latitude': 38.5598,
    'longitude': 68.7870,
    'battery_level': 42,
    'updated_at': _iso(DateTime.now()),
  };
  final apps = child['apps'] as List;
  (apps.first as Map<String, dynamic>)['first_seen_at'] = _iso(
    DateTime.now().subtract(const Duration(hours: 2)),
  );
  return snap;
}

/// Routes requests; records every non-GET call as (method path, body).
class FakeServer {
  FakeServer(this.snapshot);
  Map<String, dynamic> snapshot;
  final calls = <(String, Object?)>[];
  final Map<String, Object> getResponses = {};

  late final NigohApi api = NigohApi(client: MockClient(handle));

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    if (r.method != 'GET') {
      calls.add((
        '${r.method} $path',
        r.body.isEmpty ? null : jsonDecode(r.body),
      ));
      return jsonResponse({'status': 'success'});
    }
    for (final entry in getResponses.entries) {
      if (path.endsWith(entry.key)) return jsonResponse(entry.value);
    }
    if (path.endsWith('/places')) return jsonResponse({'places': []});
    return jsonResponse(snapshot);
  }
}

/// Deep-compares a recorded (path, body) call.
void expectCall((String, Object?) actual, (String, Object?) expected) {
  expect(actual.$1, expected.$1);
  expect(actual.$2, expected.$2);
}

Future<FamilyController> loadedController(FakeServer server) async {
  final c = FamilyController(server.api, pollInterval: null);
  await c.refresh();
  return c;
}

void main() {
  group('pure logic', () {
    test('category classifier', () {
      expect(classifyApp('com.roblox.client', 'Roblox'), AppCategory.games);
      expect(classifyApp('com.mojang.minecraftpe'), AppCategory.games);
      expect(classifyApp('com.supercell.brawlstars'), AppCategory.games);
      expect(classifyApp('org.telegram.messenger'), AppCategory.social);
      expect(classifyApp('com.instagram.android'), AppCategory.social);
      expect(classifyApp('com.whatsapp'), AppCategory.social);
      expect(classifyApp('com.google.android.youtube'), AppCategory.video);
      expect(
        classifyApp('com.zhiliaoapp.musically', 'TikTok'),
        AppCategory.video,
      );
      expect(classifyApp('com.duolingo'), AppCategory.education);
      expect(classifyApp('org.khanacademy.android'), AppCategory.education);
      expect(classifyApp('com.android.calculator2'), AppCategory.other);
      expect(classifyApp('com.google.android.calendar'), AppCategory.other);
    });

    test('safe place inside / outside (haversine)', () {
      const home = SafePlace(
        id: 1,
        name: 'Хона',
        latitude: 38.5598,
        longitude: 68.7870,
        radiusMeters: 150,
      );
      const school = SafePlace(
        id: 2,
        name: 'Мактаб',
        latitude: 38.5800,
        longitude: 68.7900,
        radiusMeters: 200,
      );
      // ~1 km per 0.009° latitude.
      expect(distanceMeters(38.0, 68.0, 38.009, 68.0), closeTo(1000, 10));
      const nearHome = ChildLocation(latitude: 38.5605, longitude: 68.7872);
      const far = ChildLocation(latitude: 38.5700, longitude: 68.7870);
      expect(placeStatus(nearHome, [home, school]), 'Дар Хона');
      expect(placeStatus(far, [home, school]), 'Берун аз ҷойҳои бехатар');
      expect(placeStatus(far, const []), isNull);
      expect(placeStatus(null, [home]), isNull);
    });

    test('bedtime over midnight', () {
      const b = Bedtime(enabled: true, start: '21:30', end: '07:00');
      expect(b.activeAt(DateTime(2026, 1, 1, 23, 0)), isTrue);
      expect(b.activeAt(DateTime(2026, 1, 1, 6, 59)), isTrue);
      expect(b.activeAt(DateTime(2026, 1, 1, 12, 0)), isFalse);
      expect(bedtimeLabel(b), 'Вақти хоб: 21:30–07:00');
    });
  });

  group('overview', () {
    Future<FakeServer> pumpHome(
      WidgetTester tester,
      Map<String, dynamic> snap,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = FakeServer(snap);
      final c = FamilyController(server.api, pollInterval: null);
      addTearDown(c.dispose);
      await tester.runAsync(c.refresh);
      await tester.pumpWidget(
        SessionScope(
          session: Session(api: server.api),
          child: MaterialApp(home: ParentHome(controller: c)),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      return server;
    }

    testWidgets('SOS banner shows child, message and actions', (tester) async {
      await pumpHome(
        tester,
        richSnapshot(
          lastUrgent: {
            'id': 99,
            'sender_role': 'child',
            'sender_name': 'Сино',
            'message_type': 'urgent',
            'content': 'Ман гум шудам',
            'created_at': _iso(DateTime.now()),
          },
        ),
      );
      expect(find.byType(SosBanner), findsOneWidget);
      expect(find.text('Сино кӯмак мехоҳад'), findsOneWidget);
      expect(find.text('Ман гум шудам'), findsOneWidget);
      expect(find.text('Кушодани чат'), findsOneWidget);
      expect(find.text('Ҷойгиршавӣ'), findsOneWidget);
    });

    testWidgets('no SOS banner without an urgent message', (tester) async {
      await pumpHome(tester, richSnapshot());
      expect(find.byType(SosBanner), findsNothing);
    });

    testWidgets('card shows battery, bedtime, requests and new apps', (
      tester,
    ) async {
      await pumpHome(
        tester,
        richSnapshot(
          pending: 2,
          unread: 3,
          bedtime: {'enabled': true, 'start': '21:30', 'end': '07:00'},
        ),
      );
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('Вақти хоб: 21:30–07:00'), findsOneWidget);
      expect(find.text('2 дархост'), findsOneWidget);
      expect(find.text('1 барномаи нав'), findsOneWidget);
      expect(find.text('3 паёми нав'), findsOneWidget);
      expect(find.byKey(const ValueKey('requests-badge')), findsOneWidget);
      // Unread badge on the Чат destination.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('nav-chat')),
          matching: find.text('3'),
        ),
        findsWidgets,
      );
    });
  });

  test('markChatRead posts to the read endpoint and refreshes', () async {
    final server = FakeServer(richSnapshot(unread: 2));
    final c = await loadedController(server);
    server.snapshot = richSnapshot();
    await c.markChatRead(7);
    expect(server.calls.single.$1, 'POST /api/mobile/v2/children/7/chat/read');
    expect(c.unreadTotal, 0);
  });

  testWidgets('approving a request sends the chosen minutes', (tester) async {
    final server = FakeServer(richSnapshot(pending: 1));
    server.getResponses['/requests'] = {
      'requests': [
        {
          'id': 5,
          'package_name': 'com.roblox.client',
          'requested_minutes': 20,
          'reason': 'Бо дӯстон бозӣ',
          'status': 'pending',
          'created_at': _iso(DateTime.now()),
        },
        {
          'id': 4,
          'package_name': 'com.roblox.client',
          'app_name': 'Roblox',
          'requested_minutes': 15,
          'status': 'denied',
          'created_at': _iso(DateTime.now().subtract(const Duration(hours: 3))),
        },
      ],
    };
    late FamilyController c;
    await tester.runAsync(() async => c = await loadedController(server));
    await tester.pumpWidget(
      MaterialApp(home: TimeRequestsScreen(controller: c)),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('«Бо дӯстон бозӣ»'), findsOneWidget);
    expect(find.text('+20 дақ'), findsOneWidget);
    expect(find.text('Ҷавобҳои охирин'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('approve-5')));
    await tester.pumpAndSettle();
    expect(find.text('+20 дақ (дархост)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grant-30')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expectCall(server.calls.first, (
      'POST /api/mobile/v2/children/7/requests/5/decision',
      {'approve': true, 'minutes': 30},
    ));
  });

  testWidgets('denying a request sends approve false', (tester) async {
    final server = FakeServer(richSnapshot(pending: 1));
    server.getResponses['/requests'] = {
      'requests': [
        {
          'id': 6,
          'package_name': 'com.roblox.client',
          'app_name': 'Roblox',
          'requested_minutes': 15,
          'status': 'pending',
        },
      ],
    };
    late FamilyController c;
    await tester.runAsync(() async => c = await loadedController(server));
    await tester.pumpWidget(
      MaterialApp(home: TimeRequestsScreen(controller: c)),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deny-6')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expectCall(server.calls.first, (
      'POST /api/mobile/v2/children/7/requests/6/decision',
      {'approve': false},
    ));
  });

  group('apps', () {
    Future<(FakeServer, FamilyController)> pumpApps(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = FakeServer(richSnapshot());
      late FamilyController c;
      await tester.runAsync(() async => c = await loadedController(server));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppsScreen(controller: c)),
        ),
      );
      await tester.pumpAndSettle();
      return (server, c);
    }

    testWidgets('bonus button posts minutes and shows today bonus', (
      tester,
    ) async {
      final (server, c) = await pumpApps(tester);
      await tester.tap(
        find.byKey(const ValueKey('bonus-com.roblox.client-15')),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expectCall(server.calls.single, (
        'POST /api/mobile/v2/children/7/apps/com.roblox.client/bonus',
        {'minutes': 15},
      ));
      expect(c.selected!.apps.first.bonusMinutesToday, 15);
      expect(find.text('+15 дақ имрӯз'), findsOneWidget);
    });

    testWidgets('always allowed toggle sends always_allowed', (tester) async {
      final (server, c) = await pumpApps(tester);
      await tester.tap(find.byKey(const ValueKey('options-com.roblox.client')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ҳеҷ гоҳ бо танаффус'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('always-com.roblox.client')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expectCall(server.calls.single, (
        'PUT /api/mobile/v2/children/7/apps/com.roblox.client',
        {'always_allowed': true},
      ));
      expect(c.selected!.apps.first.alwaysAllowed, isTrue);
    });

    testWidgets('new and category filters, block a whole category', (
      tester,
    ) async {
      final (server, _) = await pumpApps(tester);
      expect(find.text('Нав'), findsOneWidget);
      await tester.tap(find.text('Нав (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Roblox'), findsOneWidget);
      expect(find.text('Telegram'), findsNothing);

      await tester.tap(find.text('Бозиҳо (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-block')));
      await tester.pumpAndSettle();
      expect(find.text('Ҳамаи бозиҳоро бастан?'), findsOneWidget);
      await tester.tap(find.text('Бастан'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expectCall(server.calls.single, (
        'PUT /api/mobile/v2/children/7/apps/com.roblox.client',
        {'is_blocked': true},
      ));
    });
  });

  testWidgets('bedtime save sends the correct JSON', (tester) async {
    final server = FakeServer(richSnapshot());
    late FamilyController c;
    await tester.runAsync(() async => c = await loadedController(server));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BedtimeSheet(controller: c, child: c.selected!),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('bedtime-switch')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bedtime-save')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expectCall(server.calls.single, (
      'PUT /api/mobile/v2/children/7/settings',
      {
        'bedtime': {'enabled': true, 'start': '21:30', 'end': '07:00'},
      },
    ));
    expect(c.selected!.bedtime.enabled, isTrue);
  });

  testWidgets('weekly chart renders 7 bars and selects a day', (tester) async {
    final today = DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--)
        {
          'date': today
              .subtract(Duration(days: i))
              .toIso8601String()
              .substring(0, 10),
          'minutes': 30 + i * 10,
          'top': [
            {
              'package_name': 'com.app$i',
              'app_name': 'Барнома $i',
              'minutes': 30 + i * 10,
            },
          ],
        },
    ];
    final server = FakeServer(richSnapshot());
    server.getResponses['/usage'] = {'days': days};
    final child = FamilyChild.fromJson(
      ((richSnapshot()['children'] as List).first as Map)
          .cast<String, dynamic>(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyReportScreen(api: server.api, child: child),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(ValueKey('report-bar-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('report-bar-7')), findsNothing);
    // Today (last bar) is selected: its top app is listed.
    expect(find.text('Барнома 0'), findsOneWidget);
    expect(find.text('Имрӯз'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('report-bar-0')));
    await tester.pumpAndSettle();
    expect(find.text('Барнома 6'), findsOneWidget);
    expect(find.text('Барнома 0'), findsNothing);
  });
}
