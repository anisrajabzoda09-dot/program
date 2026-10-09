import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/features/child/child_home.dart';
import 'package:nigoh_family_parent/core/user_journey_logic.dart';
import 'package:nigoh_family_parent/features/child/child_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> serverChild({bool paired = true}) => {
  'id': 5,
  'name': 'Алӣ',
  'gender': 'boy',
  'age': 10,
  'pairing_code': '482913',
  'is_paired': paired,
  'parent_name': 'Модар',
  'apps': [
    {
      'package_name': 'com.game',
      'app_name': 'Game',
      'is_blocked': true,
      'daily_limit_minutes': 0,
      'schedule': null,
      'usage_minutes_today': 12,
    },
    {
      'package_name': 'com.video',
      'app_name': 'Video',
      'is_blocked': false,
      'daily_limit_minutes': 60,
      'schedule': {
        'enabled': true,
        'start': '16:00',
        'end': '18:00',
        'weekdays': [1, 2, 3],
      },
      'usage_minutes_today': 0,
    },
  ],
  'location': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tj.nigoh/device_control');
  late List<MethodCall> nativeCalls;
  late List<Object?> installedApps;
  late List<Object?> usageStats;

  setUp(() {
    nativeCalls = [];
    installedApps = [
      {
        'packageName': 'com.game',
        'appName': 'Game',
        'isSystemApp': false,
        'iconBase64': 'AAAA',
      },
      {'packageName': 'com.video', 'appName': 'Video', 'isSystemApp': false},
      {'packageName': '', 'appName': 'broken'},
    ];
    usageStats = [
      {'packageName': 'com.game', 'minutes': 5000, 'lastUsedAt': 1760000000000},
      {'packageName': 'com.video', 'minutes': -4, 'lastUsedAt': 0},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          switch (call.method) {
            case 'getInstalledApps':
              return installedApps;
            case 'getUsageStats':
              return usageStats;
            case 'getProtectionStatus':
              return {
                'usage': true,
                'overlay': false,
                'accessibility': true,
                'location': true,
                'notifications': true,
              };
          }
          return null;
        });
    SharedPreferences.setMockInitialValues({
      'nigoh.child_profile': ['Алӣ', 'boy', '10'],
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  ChildSync makeSync(MockClient client) => ChildSync(
    api: NigohApi(client: client, baseUrl: 'http://t'),
    trackLocation: false,
    listenPackageEvents: false,
  );

  test('no child on the server → pair code created from the profile', () async {
    Map<String, dynamic>? codeBody;
    final sync = makeSync(
      MockClient((req) async {
        if (req.url.path == '/api/mobile/v2/snapshot') {
          return json({'child': null});
        }
        if (req.url.path == '/api/mobile/v2/pair/code') {
          codeBody = jsonDecode(req.body) as Map<String, dynamic>;
          return json({
            'child_id': 5,
            'pairing_code': '482913',
            'paired': false,
          });
        }
        return json({}, 404);
      }),
    );
    await sync.ensureChild();
    expect(codeBody, {'child_name': 'Алӣ', 'gender': 'boy', 'age': 10});
    expect(sync.childId, 5);
    expect(sync.pairingCode, '482913');
    expect(sync.paired, isFalse);
    expect(sync.loading, isFalse);
    expect(sync.lastError, isNull);
    // QR payload stays compatible with the parent's scanner.
    expect(UserJourneyLogic.pairingCode(pairingQrData('482913')), '482913');
    sync.dispose();
  });

  test('paired snapshot pushes rules to the native blocker', () async {
    final sync = makeSync(
      MockClient((req) async {
        if (req.url.path == '/api/mobile/v2/snapshot') {
          return json({'child': serverChild()});
        }
        return json({'status': 'success'});
      }),
    );
    await sync.tick();
    await sync.syncApps();
    expect(sync.paired, isTrue);
    expect(sync.parentName, 'Модар');
    final push = nativeCalls.lastWhere((c) => c.method == 'setAppControlRules');
    final rules = (push.arguments as Map)['rules'] as List;
    expect(rules, [
      {
        'packageName': 'com.game',
        'blocked': true,
        'dailyLimitMinutes': 0,
        'schedule': null,
      },
      {
        'packageName': 'com.video',
        'blocked': false,
        'dailyLimitMinutes': 60,
        'schedule': {
          'enabled': true,
          'start': '16:00',
          'end': '18:00',
          'weekdays': [1, 2, 3],
        },
      },
    ]);
    expect(sync.missingPermissions, ['Экрани муҳофизат']);
    sync.dispose();
  });

  test('unpaired child gets an empty rule list', () async {
    final sync = makeSync(
      MockClient((req) async => json({'child': serverChild(paired: false)})),
    );
    await sync.ensureChild();
    final push = nativeCalls.lastWhere((c) => c.method == 'setAppControlRules');
    expect((push.arguments as Map)['rules'], isEmpty);
    sync.dispose();
  });

  test('app upload clamps usage and nulls missing last-used time', () async {
    List<dynamic>? uploaded;
    bool? snapshotComplete;
    final sync = makeSync(
      MockClient((req) async {
        if (req.url.path == '/api/mobile/v2/snapshot') {
          return json({'child': serverChild()});
        }
        if (req.url.path == '/api/mobile/v2/children/5/apps/sync') {
          final body = jsonDecode(req.body) as Map;
          uploaded = body['apps'] as List;
          snapshotComplete = body['snapshot_complete'] as bool?;
          return json({'status': 'success'});
        }
        return json({}, 404);
      }),
    );
    await sync.ensureChild();
    await sync.syncApps();
    expect(uploaded, hasLength(2));
    final game = uploaded!.firstWhere((a) => a['package_name'] == 'com.game');
    final video = uploaded!.firstWhere((a) => a['package_name'] == 'com.video');
    expect(game['usage_minutes'], 1440);
    expect(game['last_used_at'], isNotNull);
    expect(game['icon_base64'], 'AAAA');
    expect(video['usage_minutes'], 0);
    expect(video['last_used_at'], isNull);
    expect(sync.appsCount, 2);
    expect(snapshotComplete, isTrue);
    expect(sync.lastAppsSync, isNotNull);
    expect(ChildSync.clampUsage(-1), 0);
    expect(ChildSync.clampUsage(99999), 1440);
    sync.dispose();
  });

  test('a verified empty installed-app snapshot is uploaded', () async {
    installedApps = [];
    Map<String, dynamic>? uploaded;
    final sync = makeSync(
      MockClient((req) async {
        if (req.url.path == '/api/mobile/v2/snapshot') {
          return json({'child': serverChild()});
        }
        if (req.url.path == '/api/mobile/v2/children/5/apps/sync') {
          uploaded = jsonDecode(req.body) as Map<String, dynamic>;
          return json({'status': 'success'});
        }
        return json({}, 404);
      }),
    );
    await sync.ensureChild();
    await sync.syncApps();
    expect(uploaded?['apps'], isEmpty);
    expect(uploaded?['snapshot_complete'], isTrue);
    expect(sync.lastError, isNull);
    sync.dispose();
  });

  test('failed upload keeps a readable error until it succeeds', () async {
    var fail = true;
    final sync = makeSync(
      MockClient((req) async {
        if (req.url.path == '/api/mobile/v2/snapshot') {
          return json({'child': serverChild()});
        }
        if (fail) return json({'detail': 'Сервер банд аст'}, 503);
        return json({'status': 'success'});
      }),
    );
    await sync.ensureChild();
    await sync.syncApps();
    expect(sync.lastError, contains('Сервер банд аст'));
    expect(sync.lastAppsSync, isNull);
    fail = false;
    await sync.syncApps();
    expect(sync.lastError, isNull);
    expect(sync.lastAppsSync, isNotNull);
    sync.dispose();
  });

  test('snapshot error is exposed, not swallowed', () async {
    final sync = makeSync(
      MockClient((_) async => json({'detail': 'Токен нодуруст'}, 403)),
    );
    await sync.ensureChild();
    expect(sync.lastError, 'Токен нодуруст');
    expect(sync.loading, isFalse);
    sync.dispose();
  });

  test('regenerateCode asks for a new code while not paired', () async {
    var codes = 0;
    final sync = makeSync(
      MockClient((req) async {
        if (req.url.path == '/api/mobile/v2/pair/code') {
          codes++;
          return json({
            'child_id': 5,
            'pairing_code': codes == 1 ? '111111' : '222222',
            'paired': false,
          });
        }
        return json({'child': null});
      }),
    );
    await sync.ensureChild();
    expect(sync.pairingCode, '111111');
    await sync.regenerateCode();
    expect(sync.pairingCode, '222222');
    sync.dispose();
  });
}
