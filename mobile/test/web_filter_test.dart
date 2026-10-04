// Файл: санҷишҳои филтри сайтҳо — модел, равзанаи волидайн, ҳамоҳангсозӣ ва корти фарзанд.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/models.dart';
import 'package:nigoh_family_parent/features/child/child_sync.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/web_filter_sheet.dart';

import 'family_controller_test.dart' show jsonResponse, snapshotJson;
import 'parent_features_test.dart' show FakeServer, expectCall;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebFilter model', () {
    test('parses levels, list, state and time', () {
      final f = WebFilter.fromJson({
        'level': 'kids',
        'blocked': ['tiktok.com', ''],
        'state': 'active',
        'reported_at': '2026-10-04T10:00:00+00:00',
      });
      expect(f.level, 'kids');
      expect(f.enabled, isTrue);
      expect(f.blocked, ['tiktok.com']);
      expect(f.state, WebFilter.stateActive);
      expect(f.reportedAt, DateTime.utc(2026, 10, 4, 10));
      expect(f.toJson(), {
        'level': 'kids',
        'blocked': ['tiktok.com'],
      });
    });

    test('unknown or missing data falls back to off', () {
      expect(WebFilter.fromJson(null).level, WebFilter.levelOff);
      expect(WebFilter.fromJson({'level': 'adult'}).enabled, isFalse);
      expect(WebFilter.fromJson({'level': 'teen', 'state': ''}).state, isNull);
      expect(WebFilter.fromJson('x').blocked, isEmpty);
    });

    test('suggested level follows age', () {
      expect(WebFilter.suggestedLevel(7), WebFilter.levelKids);
      expect(WebFilter.suggestedLevel(12), WebFilter.levelKids);
      expect(WebFilter.suggestedLevel(13), WebFilter.levelTeen);
      expect(WebFilter.suggestedLevel(17), WebFilter.levelTeen);
      expect(WebFilter.suggestedLevel(18), WebFilter.levelOff);
      expect(WebFilter.suggestedLevel(0), WebFilter.levelKids);
    });

    test('normalizeDomain matches the server rules', () {
      final n = WebFilter.normalizeDomain;
      expect(n('https://www.YouTube.com/watch?v=1'), 'youtube.com');
      expect(n('m.facebook.com'), 'm.facebook.com');
      expect(n('roblox.com.'), 'roblox.com');
      expect(n('site.tj:8080/x'), 'site.tj');
      for (final bad in [
        '',
        'localhost',
        '192.168.1.1',
        '-x.com',
        'a..b',
        'has space.com',
      ]) {
        expect(n(bad), isNull, reason: bad);
      }
    });

    test('FamilyChild reads web_filter and copyWith keeps state', () {
      final child = FamilyChild.fromJson({
        ...(snapshotJson()['children'] as List).first as Map<String, dynamic>,
        'web_filter': {'level': 'teen', 'blocked': [], 'state': 'off'},
      });
      expect(child.webFilter.level, 'teen');
      final copy = child.webFilter.copyWith(level: 'kids');
      expect(copy.level, 'kids');
      expect(copy.state, 'off');
    });
  });

  group('parent web filter sheet', () {
    Future<(FakeServer, FamilyController)> load(
      WidgetTester tester, {
      int age = 10,
      Map<String, dynamic>? filter,
    }) async {
      final snap = snapshotJson();
      final kid = (snap['children'] as List).first as Map<String, dynamic>;
      kid['age'] = age;
      kid['child_avatar'] = 'data:image/png;base64,AA==';
      if (filter != null) kid['web_filter'] = filter;
      final server = FakeServer(snap);
      final c = FamilyController(server.api, pollInterval: null);
      addTearDown(c.dispose);
      await tester.runAsync(c.refresh);
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebFilterSheet(controller: c, child: c.selected!),
          ),
        ),
      );
      return (server, c);
    }

    testWidgets('suggests the level for the age and saves cleaned sites', (
      tester,
    ) async {
      final (server, c) = await load(tester, age: 10);
      expect(find.text('Барои синну сол'), findsOneWidget);
      // Пешниҳод барои 10 сола — «То 12 сола» интихоб шудааст.
      final kids = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('web-filter-kids')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(kids.properties.selected, isTrue);

      await tester.enterText(
        find.byKey(const ValueKey('web-filter-site')),
        'https://www.TikTok.com/@x',
      );
      await tester.tap(find.byKey(const ValueKey('web-filter-add')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('web-filter-chip-tiktok.com')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('web-filter-site')),
        'tiktok.com',
      );
      await tester.tap(find.byKey(const ValueKey('web-filter-add')));
      await tester.pump();
      expect(find.text('Ин сайт аллакай дар рӯйхат аст'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('web-filter-site')),
        'not a site',
      );
      await tester.tap(find.byKey(const ValueKey('web-filter-add')));
      await tester.pump();
      expect(
        find.text('Суроғаи сайтро дуруст нависед, масалан tiktok.com'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('web-filter-save')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expectCall(server.calls.single, (
        'PUT /api/mobile/v2/children/7/settings',
        {
          'web_filter': {
            'level': 'kids',
            'blocked': ['tiktok.com'],
          },
        },
      ));
      expect(c.selected!.webFilter.level, 'kids');
      // _copyChild акси фарзандро гум намекунад.
      expect(c.selected!.childAvatar, isNotNull);
    });

    testWidgets('teen is suggested at 15 and the chip can be removed', (
      tester,
    ) async {
      final (server, _) = await load(
        tester,
        age: 15,
        filter: {
          'level': 'teen',
          'blocked': ['roblox.com'],
          'state': 'needs_permission',
        },
      );
      expect(find.byKey(const ValueKey('web-filter-state')), findsOneWidget);
      expect(
        find.text('Фарзанд бояд дар телефонаш иҷозат диҳад'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('web-filter-chip-roblox.com')),
          matching: find.byTooltip('Хориҷ кардан'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('web-filter-off')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('web-filter-save')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expectCall(server.calls.single, (
        'PUT /api/mobile/v2/children/7/settings',
        {
          'web_filter': {'level': 'off', 'blocked': []},
        },
      ));
    });

    test('rolls back when the server refuses', () async {
      final api = NigohApi(
        client: MockClient((r) async {
          if (r.method == 'PUT') return jsonResponse({'detail': 'Хато'}, 400);
          return jsonResponse(snapshotJson());
        }),
      );
      final c = FamilyController(api, pollInterval: null);
      await c.refresh();
      await expectLater(
        c.setWebFilter(c.selected!, const WebFilter(level: 'kids')),
        throwsA(isA<ApiException>()),
      );
      expect(c.selected!.webFilter.enabled, isFalse);
      c.dispose();
    });

    test('state labels', () {
      expect(webFilterStateLabel(const WebFilter()), 'Филтр хомӯш аст');
      expect(
        webFilterStateLabel(const WebFilter(level: 'kids', state: 'active')),
        'Дар телефони фарзанд фаъол аст',
      );
      expect(
        webFilterStateLabel(const WebFilter(level: 'kids')),
        'Интизори телефони фарзанд',
      );
      expect(webFilterLevelLabel('teen'), '13–17 сола');
    });
  });

  group('child sync applies the filter', () {
    const channel = MethodChannel('tj.nigoh/device_control');
    late List<MethodCall> nativeCalls;
    late List<(String, Object?)> posts;
    late String nativeState;
    late Map<String, dynamic> serverFilter;

    setUp(() {
      nativeCalls = [];
      posts = [];
      nativeState = 'needs_permission';
      serverFilter = {
        'level': 'kids',
        'blocked': ['tiktok.com'],
        'state': null,
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            nativeCalls.add(call);
            if (call.method == 'setWebFilter') return nativeState;
            if (call.method == 'requestWebFilterPermission') {
              nativeState = 'active';
              return true;
            }
            if (call.method == 'getProtectionStatus') return <String, Object>{};
            if (call.method == 'getInstalledApps') return <Object>[];
            if (call.method == 'getUsageStats') return <Object>[];
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    ChildSync makeSync() => ChildSync(
      api: NigohApi(
        client: MockClient((req) async {
          if (req.url.path == '/api/mobile/v2/snapshot') {
            return http.Response(
              jsonEncode({
                'child': {
                  'id': 5,
                  'name': 'Алӣ',
                  'gender': 'boy',
                  'age': 10,
                  'pairing_code': '482913',
                  'is_paired': true,
                  'apps': [],
                  'web_filter': serverFilter,
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (req.method == 'POST' &&
              req.url.path.endsWith('/web-filter/state')) {
            posts.add((req.url.path, jsonDecode(req.body)));
            serverFilter = {
              ...serverFilter,
              'state': (jsonDecode(req.body) as Map)['state'],
            };
          }
          return jsonResponse({'status': 'success'});
        }),
        baseUrl: 'http://t',
      ),
      trackLocation: false,
      listenPackageEvents: false,
    );

    test(
      'sends level and list to Android and reports the state once',
      () async {
        final sync = makeSync();
        await sync.tick();
        final call = nativeCalls.lastWhere((c) => c.method == 'setWebFilter');
        expect(call.arguments, {
          'level': 'kids',
          'blocked': ['tiktok.com'],
        });
        expect(sync.webFilterState, 'needs_permission');
        expect(posts, hasLength(1));
        expect(posts.single.$1, '/api/mobile/v2/children/5/web-filter/state');
        expect(posts.single.$2, {'state': 'needs_permission'});
        await sync.tick();
        expect(posts, hasLength(1), reason: 'same state is not reported again');
        sync.dispose();
      },
    );

    test('permission dialog turns the filter on and reports active', () async {
      final sync = makeSync();
      await sync.tick();
      expect(await sync.requestWebFilterPermission(), isTrue);
      expect(sync.webFilterState, 'active');
      expect(posts.last.$2, {'state': 'active'});
      sync.dispose();
    });

    test('filter the parent never set is not reported', () async {
      serverFilter = {'level': 'off', 'blocked': [], 'state': null};
      nativeState = 'off';
      final sync = makeSync();
      await sync.tick();
      expect(nativeCalls.where((c) => c.method == 'setWebFilter'), isNotEmpty);
      expect(posts, isEmpty);
      sync.dispose();
    });
  });
}
