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
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/study_sheet.dart';

import 'family_controller_test.dart' show jsonResponse, snapshotJson;
import 'parent_features_test.dart' show FakeServer, expectCall;

Map<String, dynamic> _app(String pkg, String name, {bool always = false}) => {
  'package_name': pkg,
  'app_name': name,
  'is_blocked': false,
  'daily_limit_minutes': 0,
  'schedule': null,
  'usage_minutes_today': 0,
  'always_allowed': always,
};

Map<String, dynamic> studyChild() => {
  'id': 5,
  'name': 'Алӣ',
  'gender': 'boy',
  'age': 10,
  'pairing_code': '482913',
  'is_paired': true,
  'parent_name': 'Модар',
  'study': {
    'enabled': true,
    'start': '08:00',
    'end': '13:00',
    'weekdays': [1, 2, 3, 4, 5, 6],
  },
  'apps': [
    _app('com.roblox.client', 'Roblox'),
    _app('com.google.android.dialer', 'Phone'),
    _app('com.duolingo', 'Duolingo'),
    _app('org.telegram.messenger', 'Telegram', always: true),
  ],
  'location': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parent study sheet', () {
    testWidgets('saves the right JSON and updates the child', (tester) async {
      final server = FakeServer(snapshotJson());
      final c = FamilyController(server.api, pollInterval: null);
      addTearDown(c.dispose);
      await tester.runAsync(c.refresh);
      expect(c.selected!.study.enabled, isFalse);

      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudySheet(controller: c, child: c.selected!),
          ),
        ),
      );
      expect(find.text(studyExplanation), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('13:00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-switch')));
      await tester.pump();
      // Saturday off, Sunday on.
      await tester.tap(find.byKey(const ValueKey('study-day-6')));
      await tester.tap(find.byKey(const ValueKey('study-day-7')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('study-save')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expectCall(server.calls.single, (
        'PUT /api/mobile/v2/children/7/settings',
        {
          'study': {
            'enabled': true,
            'start': '08:00',
            'end': '13:00',
            'weekdays': [1, 2, 3, 4, 5, 7],
          },
        },
      ));
      expect(c.selected!.study.enabled, isTrue);
      expect(studyLabel(c.selected!.study), 'Тамаркузи дарс: 08:00–13:00');
    });

    test('rolls back and rethrows when the server refuses', () async {
      final api = NigohApi(
        client: MockClient((r) async {
          if (r.method == 'PUT') {
            return jsonResponse({'detail': 'Хато'}, 400);
          }
          return jsonResponse(snapshotJson());
        }),
      );
      final c = FamilyController(api, pollInterval: null);
      await c.refresh();
      await expectLater(
        c.setStudyMode(c.selected!, const StudyMode(enabled: true)),
        throwsA(isA<ApiException>()),
      );
      expect(c.selected!.study.enabled, isFalse);
      c.dispose();
    });

    test('copying a child keeps study and battery', () async {
      final snap = snapshotJson();
      final child = (snap['children'] as List).first as Map<String, dynamic>;
      child['battery_level'] = 33;
      child['study'] = {'enabled': true, 'start': '09:00', 'end': '12:00'};
      final server = FakeServer(snap);
      final c = FamilyController(server.api, pollInterval: null);
      await c.refresh();
      final app = c.selected!.apps.first;
      await c.setBlocked(c.selected!, app, true);
      expect(c.selected!.batteryLevel, 33);
      expect(c.selected!.study.start, '09:00');
      await c.setBedtime(c.selected!, const Bedtime(enabled: true));
      expect(c.selected!.study.enabled, isTrue);
      c.dispose();
    });
  });

  group('child study rules', () {
    const channel = MethodChannel('tj.nigoh/device_control');
    late List<MethodCall> nativeCalls;

    setUp(() {
      nativeCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            nativeCalls.add(call);
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

    Map<String, bool> blockedByPackage() {
      final push = nativeCalls.lastWhere(
        (c) => c.method == 'setAppControlRules',
      );
      return {
        for (final r in (push.arguments as Map)['rules'] as List)
          (r as Map)['packageName'] as String: r['blocked'] as bool,
      };
    }

    Future<ChildSync> run(DateTime at, {bool online = true}) async {
      var clock = at;
      var up = online;
      final sync = ChildSync(
        api: NigohApi(
          client: MockClient((req) async {
            if (!up) throw http.ClientException('offline');
            if (req.url.path == '/api/mobile/v2/snapshot') {
              return http.Response(
                jsonEncode({'child': studyChild()}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return jsonResponse({'status': 'success'});
          }),
          baseUrl: 'http://t',
        ),
        trackLocation: false,
        listenPackageEvents: false,
        clock: () => clock,
      );
      await sync.tick();
      // Let tests move the clock / connectivity afterwards.
      _setClock = (t) => clock = t;
      _setOnline = (v) => up = v;
      return sync;
    }

    test(
      'during study hours games close; dialer and education stay open',
      () async {
        // Monday 2026-09-28 10:00.
        final sync = await run(DateTime(2026, 9, 28, 10, 0));
        expect(blockedByPackage(), {
          'com.roblox.client': true,
          'com.google.android.dialer': false,
          'com.duolingo': false,
          'org.telegram.messenger': false,
        });
        sync.dispose();
      },
    );

    test('outside study hours and on Sunday nothing is closed', () async {
      final sync = await run(DateTime(2026, 9, 28, 14, 0));
      expect(blockedByPackage()['com.roblox.client'], isFalse);
      sync.dispose();
      final sunday = await run(DateTime(2026, 9, 27, 10, 0));
      expect(blockedByPackage()['com.roblox.client'], isFalse);
      sunday.dispose();
    });

    test(
      'window start re-pushes rules on the next tick, even offline',
      () async {
        final sync = await run(DateTime(2026, 9, 28, 7, 59));
        expect(blockedByPackage()['com.roblox.client'], isFalse);
        _setOnline(false);
        _setClock(DateTime(2026, 9, 28, 8, 0, 15));
        await sync.tick();
        expect(blockedByPackage()['com.roblox.client'], isTrue);
        _setClock(DateTime(2026, 9, 28, 13, 0, 5));
        await sync.tick();
        expect(blockedByPackage()['com.roblox.client'], isFalse);
        sync.dispose();
      },
    );

    test('«Қоидаҳои ман» lists only apps closed by study mode', () {
      final child = FamilyChild.fromJson(studyChild());
      expect(studyClosedApps(child.apps).map((a) => a.packageName), [
        'com.roblox.client',
      ]);
    });
  });
}

void Function(DateTime) _setClock = (_) {};
void Function(bool) _setOnline = (_) {};
