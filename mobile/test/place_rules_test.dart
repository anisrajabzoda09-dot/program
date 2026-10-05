// Файл: санҷишҳои қоидаҳо аз рӯи ҷой — модел, қоидаи native, фосилаи эҳтиётӣ, телефони фарзанд ва равзанаи волидайн.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/geo.dart';
import 'package:nigoh_family_parent/core/models.dart';
import 'package:nigoh_family_parent/features/child/child_sync.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/place_rules_sheet.dart';

import 'family_controller_test.dart' show jsonResponse, snapshotJson;
import 'parent_features_test.dart' show FakeServer, expectCall;

const school = (38.5598, 68.7870);

/// Нуқтае, ки [meters] метр ба шимоли мактаб аст.
(double, double) north(double meters) =>
    (school.$1 + meters / 111195.0, school.$2);

Position pos((double, double) p, {double accuracy = 20}) => Position(
  latitude: p.$1,
  longitude: p.$2,
  timestamp: DateTime.utc(2026, 10, 5, 9),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Map<String, dynamic> app(
  String pkg,
  String name, {
  bool blocked = false,
  int limit = 0,
}) => {
  'package_name': pkg,
  'app_name': name,
  'is_blocked': blocked,
  'daily_limit_minutes': limit,
  'schedule': null,
  'usage_minutes_today': 0,
};

Map<String, dynamic> schoolJson({
  Map<String, Object> rules = const {},
  bool notify = false,
}) => {
  'id': 3,
  'name': 'Мактаб',
  'latitude': school.$1,
  'longitude': school.$2,
  'radius_meters': 150,
  'rules': rules,
  'notify': notify,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('PlaceAppRule parses and serialises', () {
      expect(
        PlaceAppRule.fromJson({'mode': 'block'}),
        const PlaceAppRule('block'),
      );
      expect(
        PlaceAppRule.fromJson({'mode': 'limit', 'minutes': 20}),
        const PlaceAppRule('limit', minutes: 20),
      );
      expect(
        PlaceAppRule.fromJson({'mode': 'allow', 'minutes': 9}),
        const PlaceAppRule('allow'),
      );
      expect(PlaceAppRule.fromJson({'mode': 'limit'}), isNull);
      expect(PlaceAppRule.fromJson({'mode': 'nuke'}), isNull);
      expect(PlaceAppRule.fromJson('x'), isNull);
      expect(const PlaceAppRule('limit', minutes: 30).toJson(), {
        'mode': 'limit',
        'minutes': 30,
      });
      expect(const PlaceAppRule('block').toJson(), {'mode': 'block'});
    });

    test('SafePlace and FamilyChild read rules and current place', () {
      final p = SafePlace.fromJson(
        schoolJson(
          rules: {
            'a': {'mode': 'block'},
            'bad': {'mode': '?'},
          },
          notify: true,
        ),
      );
      expect(p.rules, {'a': const PlaceAppRule('block')});
      expect(p.notify, isTrue);
      final kid = FamilyChild.fromJson({
        ...(snapshotJson()['children'] as List).first as Map<String, dynamic>,
        'places': [schoolJson()],
        'current_place_id': 3,
      });
      expect(kid.places.single.name, 'Мактаб');
      expect(kid.currentPlaceId, 3);
      expect(p.copyWith(notify: false).rules, p.rules);
    });

    test('toNativeRule applies the place rule', () {
      ChildApp a(Map<String, dynamic> j) => ChildApp.fromJson(j);
      final tiktok = a(app('com.zhiliaoapp.musically', 'TikTok'));
      expect(
        tiktok.toNativeRule(placeRule: const PlaceAppRule('block'))['blocked'],
        isTrue,
      );
      final dialer = a(app('com.google.android.dialer', 'Phone'));
      expect(
        dialer.toNativeRule(placeRule: const PlaceAppRule('block'))['blocked'],
        isFalse,
        reason: 'calls are never blocked',
      );
      final telegram = a(app('org.telegram.messenger', 'Telegram', limit: 60));
      expect(
        telegram.toNativeRule(
          placeRule: const PlaceAppRule('limit', minutes: 20),
        )['dailyLimitMinutes'],
        20,
      );
      expect(
        telegram.toNativeRule(
          placeRule: const PlaceAppRule('limit', minutes: 90),
        )['dailyLimitMinutes'],
        60,
        reason: 'the smaller limit wins',
      );
      final free = a(app('com.youtube', 'YouTube'));
      expect(
        free.toNativeRule(
          placeRule: const PlaceAppRule('limit', minutes: 15),
        )['dailyLimitMinutes'],
        15,
      );
      final blockedEverywhere = a(
        app('com.duolingo', 'Duolingo', blocked: true),
      );
      final open = blockedEverywhere.toNativeRule(
        bedtimeActive: true,
        placeRule: const PlaceAppRule('allow'),
      );
      expect(open['blocked'], isFalse);
      expect(open['dailyLimitMinutes'], 0);
      expect(
        tiktok.toNativeRule()['blocked'],
        isFalse,
        reason: 'no place, no change',
      );
    });

    test('placeAt keeps the child inside within the 40 m margin', () {
      final places = [SafePlace.fromJson(schoolJson())];
      expect(placeAt(north(100).$1, north(100).$2, places)?.id, 3);
      expect(placeAt(north(170).$1, north(170).$2, places), isNull);
      expect(
        placeAt(north(170).$1, north(170).$2, places, currentId: 3)?.id,
        3,
      );
      expect(
        placeAt(north(200).$1, north(200).$2, places, currentId: 3),
        isNull,
      );
    });
  });

  group('child phone', () {
    const channel = MethodChannel('tj.nigoh/device_control');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getProtectionStatus') return <String, Object>{};
            if (call.method == 'getInstalledApps' ||
                call.method == 'getUsageStats') {
              return <Object>[];
            }
            if (call.method == 'setWebFilter') return 'off';
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    Map<String, bool> blocked() {
      final push = calls.lastWhere((c) => c.method == 'setAppControlRules');
      return {
        for (final r in (push.arguments as Map)['rules'] as List)
          (r as Map)['packageName'] as String: r['blocked'] as bool,
      };
    }

    test('rules switch on at school and off after leaving, offline', () async {
      var online = true;
      final sync = ChildSync(
        api: NigohApi(
          client: MockClient((req) async {
            if (!online) throw http.ClientException('offline');
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
                    'apps': [
                      app('com.zhiliaoapp.musically', 'TikTok'),
                      app('com.google.android.dialer', 'Phone'),
                    ],
                    'places': [
                      schoolJson(
                        rules: {
                          'com.zhiliaoapp.musically': {'mode': 'block'},
                          'com.google.android.dialer': {'mode': 'block'},
                        },
                      ),
                    ],
                  },
                }),
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
      );
      await sync.tick();
      expect(blocked()['com.zhiliaoapp.musically'], isFalse);
      online = false;
      sync.onPosition(pos(north(80)));
      await Future<void>.delayed(Duration.zero);
      expect(sync.activePlace?.name, 'Мактаб');
      expect(
        blocked()['com.zhiliaoapp.musically'],
        isTrue,
        reason: 'applied without the server',
      );
      expect(blocked()['com.google.android.dialer'], isFalse);
      final pushes = calls
          .where((c) => c.method == 'setAppControlRules')
          .length;
      sync.onPosition(pos(north(175)));
      await Future<void>.delayed(Duration.zero);
      expect(
        calls.where((c) => c.method == 'setAppControlRules').length,
        pushes,
        reason: 'no re-push inside the margin',
      );
      sync.onPosition(pos(north(600), accuracy: 900));
      await Future<void>.delayed(Duration.zero);
      expect(
        sync.activePlace?.name,
        'Мактаб',
        reason: 'a bad fix does not move the child',
      );
      sync.onPosition(pos(north(600)));
      await Future<void>.delayed(Duration.zero);
      expect(sync.activePlace, isNull);
      expect(blocked()['com.zhiliaoapp.musically'], isFalse);
      sync.dispose();
    });
  });

  group('parent sheet', () {
    testWidgets('quick school button, a limit from the menu, alerts on, save', (
      tester,
    ) async {
      final snap = snapshotJson(
        apps: [
          app('com.roblox.client', 'Roblox'),
          app('org.telegram.messenger', 'Telegram'),
          app('com.google.android.dialer', 'Phone'),
        ],
      );
      final server = FakeServer(snap);
      server.getResponses['/places'] = {
        'places': [schoolJson()],
      };
      final c = FamilyController(server.api, pollInterval: null);
      addTearDown(c.dispose);
      await tester.runAsync(c.refresh);
      await tester.runAsync(() => c.loadPlaces(7));
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceRulesSheet(
              controller: c,
              child: c.selected!,
              place: c.placesFor(7).single,
            ),
          ),
        ),
      );
      expect(find.text('Қоидаҳои «Мактаб»'), findsOneWidget);
      expect(find.text('Занг ва SMS ҳамеша кушода'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('place-quick-school')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('place-rule-com.roblox.client')),
          matching: find.text('Баста'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('place-menu-org.telegram.messenger')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Лимит 20 дақ').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('place-notify')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('place-save')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expectCall(server.calls.last, (
        'PUT /api/mobile/v2/children/7/places/3',
        {
          'rules': {
            'apps': {
              'com.roblox.client': {'mode': 'block'},
              'org.telegram.messenger': {'mode': 'limit', 'minutes': 20},
            },
            'notify': true,
          },
        },
      ));
      expect(c.placesFor(7).single.notify, isTrue);
    });

    test('summary text', () {
      expect(placeRulesSummary(SafePlace.fromJson(schoolJson())), 'қоида нест');
      expect(
        placeRulesSummary(
          SafePlace.fromJson(
            schoolJson(
              rules: {
                'a': {'mode': 'block'},
              },
              notify: true,
            ),
          ),
        ),
        '1 қоида · огоҳӣ',
      );
      expect(
        placeRuleLabel(const PlaceAppRule('limit', minutes: 30)),
        'Лимит 30 дақ',
      );
      expect(placeRuleLabel(null), 'Мисли ҳамеша');
    });
  });
}
