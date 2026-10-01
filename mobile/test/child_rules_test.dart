import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/models.dart';
import 'package:nigoh_family_parent/features/child/child_rules.dart';
import 'package:nigoh_family_parent/features/child/child_sync.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> app(
  String pkg,
  String name, {
  bool blocked = false,
  int limit = 0,
  int usage = 0,
  int bonus = 0,
  bool always = false,
  Map<String, dynamic>? schedule,
}) => {
  'package_name': pkg,
  'app_name': name,
  'is_blocked': blocked,
  'daily_limit_minutes': limit,
  'usage_minutes_today': usage,
  'bonus_minutes_today': bonus,
  'always_allowed': always,
  'schedule': schedule,
};

Map<String, dynamic> serverChild({
  List<Map<String, dynamic>>? apps,
  Map<String, dynamic>? bedtime,
}) => {
  'id': 5,
  'name': 'Алӣ',
  'pairing_code': '482913',
  'is_paired': true,
  'parent_name': 'Модар',
  'apps':
      apps ??
      [
        app('com.game', 'Game', blocked: true),
        app('com.video', 'Video', limit: 45, usage: 45, bonus: 15),
        app(
          'com.school',
          'School',
          schedule: {
            'enabled': true,
            'start': '16:00',
            'end': '18:00',
            'weekdays': [1, 2, 3],
          },
        ),
        app('com.maps', 'Maps', always: true),
      ],
  'bedtime': bedtime ?? {'enabled': true, 'start': '21:30', 'end': '07:00'},
};

void main() {
  const channel = MethodChannel('tj.nigoh/device_control');
  late List<MethodCall> nativeCalls;

  setUp(() {
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('labels', () {
    expect(weekdaysLabel([3, 1, 2]), 'Дш, Сш, Чш');
    expect(weekdaysLabel([1, 2, 3, 4, 5, 6, 7]), 'Ҳар рӯз');
    expect(
      limitUsageLabel(
        const ChildApp(
          packageName: 'a',
          name: 'A',
          dailyLimitMinutes: 45,
          bonusMinutesToday: 15,
          usageMinutesToday: 45,
        ),
      ),
      '45/60 дақ, +15 бонус',
    );
    expect(minutesLabel(65), '1 соат 5 дақ');
    expect(minutesLabel(40), '40 дақ');
  });

  test('active bedtime blocks everything except always-allowed apps', () async {
    final sync = ChildSync(
      api: NigohApi(
        client: MockClient((_) async => json({'child': serverChild()})),
        baseUrl: 'http://t',
      ),
      trackLocation: false,
      listenPackageEvents: false,
      clock: () => DateTime(2026, 10, 1, 22),
    );
    await sync.ensureChild();
    final rules =
        (nativeCalls.lastWhere((c) => c.method == 'setAppControlRules').arguments
                as Map)['rules']
            as List;
    final byPkg = <Object?, dynamic>{for (final r in rules) (r as Map)['packageName']: r};
    expect(byPkg['com.video']['blocked'], isTrue);
    expect(byPkg['com.video']['dailyLimitMinutes'], 60); // limit + bonus
    expect(byPkg['com.school']['blocked'], isTrue);
    expect(byPkg['com.maps']['blocked'], isFalse);
    sync.dispose();
  });

  Future<(ChildSync, List<http.Request>)> pump(
    WidgetTester tester, {
    Map<String, dynamic>? child,
    int requestStatus = 200,
    List<Map<String, dynamic>> requests = const [],
  }) async {
    final calls = <http.Request>[];
    final sync = ChildSync(
      api: NigohApi(
        client: MockClient((req) async {
          calls.add(req);
          if (req.url.path == '/api/mobile/v2/snapshot') {
            return json({'child': child ?? serverChild()});
          }
          if (req.url.path == '/api/mobile/v2/children/5/requests') {
            if (req.method == 'POST') {
              if (requestStatus != 200) {
                return json({'detail': 'pending'}, requestStatus);
              }
              return json({'status': 'success', 'id': 3});
            }
            return json({'requests': requests});
          }
          return json({'status': 'success'});
        }),
        baseUrl: 'http://t',
      ),
      trackLocation: false,
      listenPackageEvents: false,
      clock: () => DateTime(2026, 10, 1, 22),
    );
    await sync.ensureChild();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChildRulesScreen(sync: sync))),
    );
    await tester.pumpAndSettle();
    return (sync, calls);
  }

  Future<void> finish(WidgetTester tester, ChildSync sync) async {
    await tester.pumpWidget(const SizedBox());
    sync.dispose();
  }

  testWidgets('lists blocked, limited, scheduled, allowed and bedtime', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final (sync, _) = await pump(
      tester,
      requests: [
        {
          'id': 1,
          'package_name': 'com.game',
          'app_name': 'Game',
          'requested_minutes': 30,
          'status': 'approved',
        },
        {
          'id': 2,
          'package_name': 'com.video',
          'app_name': 'Video',
          'requested_minutes': 15,
          'status': 'pending',
        },
        {
          'id': 3,
          'package_name': 'com.game',
          'app_name': 'Game',
          'requested_minutes': 60,
          'status': 'denied',
        },
      ],
    );
    expect(find.text('Қоидаҳои ман'), findsOneWidget);
    expect(find.text('21:30 – 07:00'), findsOneWidget);
    expect(find.text('Ҳозир фаъол'), findsOneWidget);
    expect(find.text('Баста (1)'), findsOneWidget);
    expect(find.text('Game'), findsWidgets);
    expect(find.text('45/60 дақ, +15 бонус'), findsOneWidget);
    expect(find.text('Вақт тамом'), findsNothing); // bonus still left
    expect(find.text('16:00 – 18:00 · Дш, Сш, Чш'), findsOneWidget);
    expect(find.text('Maps'), findsOneWidget);
    expect(find.text('Вақти иловагӣ пурсидан'), findsNWidgets(2));
    expect(find.text('Дархостҳои ман'), findsOneWidget);
    expect(find.text('интизор'), findsOneWidget);
    expect(find.text('иҷозат дода шуд'), findsOneWidget);
    expect(find.text('рад шуд'), findsOneWidget);
    await finish(tester, sync);
  });

  testWidgets('empty state when there are no rules', (tester) async {
    final (sync, _) = await pump(
      tester,
      child: serverChild(
        apps: [app('com.a', 'A')],
        bedtime: {'enabled': false},
      ),
    );
    expect(find.text('Ҳоло қоида нест'), findsOneWidget);
    await finish(tester, sync);
  });

  testWidgets('asking for extra time posts the request', (tester) async {
    final (sync, calls) = await pump(tester);
    await tester.tap(find.text('Вақти иловагӣ пурсидан').first);
    await tester.pumpAndSettle();
    expect(find.text('Вақти иловагӣ барои «Game»'), findsOneWidget);
    await tester.tap(find.text('30 дақ'));
    await tester.enterText(find.byType(TextField), 'Барои дарс');
    await tester.tap(find.text('Фиристодан'));
    await tester.pumpAndSettle();
    final post = calls.lastWhere(
      (r) => r.method == 'POST' && r.url.path.endsWith('/requests'),
    );
    expect(jsonDecode(post.body), {
      'package_name': 'com.game',
      'minutes': 30,
      'reason': 'Барои дарс',
    });
    expect(find.text('Дархост фиристода шуд'), findsOneWidget);
    await finish(tester, sync);
  });

  testWidgets('409 tells the child a request is already pending', (
    tester,
  ) async {
    final (sync, _) = await pump(tester, requestStatus: 409);
    await tester.tap(find.text('Вақти иловагӣ пурсидан').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фиристодан'));
    await tester.pumpAndSettle();
    expect(find.textContaining('аллакай дархост ҳаст'), findsOneWidget);
    await finish(tester, sync);
  });

  testWidgets('request list error is shown with retry', (tester) async {
    var fail = true;
    final sync = ChildSync(
      api: NigohApi(
        client: MockClient((req) async {
          if (req.url.path == '/api/mobile/v2/snapshot') {
            return json({'child': serverChild()});
          }
          if (fail) return json({'detail': 'Сервер банд аст'}, 503);
          return json({'requests': []});
        }),
        baseUrl: 'http://t',
      ),
      trackLocation: false,
      listenPackageEvents: false,
    );
    await sync.ensureChild();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChildRulesScreen(sync: sync))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Сервер банд аст'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Аз нав'));
    await tester.pumpAndSettle();
    expect(find.text('Ҳоло дархост нафиристодаед.'), findsOneWidget);
    await finish(tester, sync);
  });
}
