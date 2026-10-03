import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';

Map<String, dynamic> snapshotJson({List<Map<String, dynamic>>? apps}) => {
  'children': [
    {
      'id': 7,
      'name': 'Сино',
      'gender': 'boy',
      'age': 10,
      'pairing_code': '123456',
      'is_paired': true,
      'apps':
          apps ??
          [
            {
              'package_name': 'com.roblox.client',
              'app_name': 'Roblox',
              'app_icon': '',
              'is_blocked': false,
              'daily_limit_minutes': 60,
              'schedule': null,
              'usage_minutes_today': 25,
            },
            {
              'package_name': 'org.telegram.messenger',
              'app_name': 'Telegram',
              'app_icon': '',
              'is_blocked': true,
              'daily_limit_minutes': 0,
              'schedule': {
                'enabled': true,
                'start': '08:00',
                'end': '13:00',
                'weekdays': [1, 2, 3, 4, 5],
              },
              'usage_minutes_today': 10,
            },
          ],
      'location': null,
    },
  ],
};

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('loads the snapshot into children and apps', () async {
    final api = NigohApi(
      client: MockClient((_) async => jsonResponse(snapshotJson())),
    );
    final c = FamilyController(api, pollInterval: null);
    await c.refresh();
    expect(c.error, isNull);
    expect(c.children, hasLength(1));
    expect(c.selected!.name, 'Сино');
    expect(c.selected!.apps.map((a) => a.name), ['Roblox', 'Telegram']);
    expect(c.selected!.blockedCount, 1);
    expect(c.selected!.usageMinutesToday, 35);
  });

  test('setBlocked sends PUT with is_blocked and updates state', () async {
    http.Request? put;
    final api = NigohApi(
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          put = request;
          return jsonResponse({'ok': true});
        }
        return jsonResponse(snapshotJson());
      }),
    );
    final c = FamilyController(api, pollInterval: null);
    await c.refresh();
    final child = c.selected!;
    await c.setBlocked(child, child.apps.first, true);
    expect(put, isNotNull);
    expect(put!.url.path, '/api/mobile/v2/children/7/apps/com.roblox.client');
    expect(jsonDecode(put!.body), {'is_blocked': true});
    expect(c.selected!.apps.first.blocked, isTrue);
  });

  test('failed update rolls back and rethrows the server message', () async {
    final api = NigohApi(
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          return jsonResponse({'detail': 'Фарзанд ёфт нашуд'}, 404);
        }
        return jsonResponse(snapshotJson());
      }),
    );
    final c = FamilyController(api, pollInterval: null);
    await c.refresh();
    final child = c.selected!;
    await expectLater(
      c.setLimit(child, child.apps.first, 120),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Фарзанд ёфт нашуд',
        ),
      ),
    );
    expect(c.selected!.apps.first.dailyLimitMinutes, 60);
  });

  test('refresh failure keeps a visible error string', () async {
    final api = NigohApi(
      client: MockClient((_) async => jsonResponse({'detail': 'Хатогӣ'}, 500)),
    );
    final c = FamilyController(api, pollInterval: null);
    await c.refresh();
    expect(c.error, 'Хатогӣ');
    expect(c.children, isEmpty);
  });

  test('unlink removes optimistically and restores on failure', () async {
    final api = NigohApi(
      client: MockClient((request) async {
        if (request.method == 'DELETE') {
          return jsonResponse({'detail': 'Иҷозат нест'}, 403);
        }
        return jsonResponse(snapshotJson());
      }),
    );
    final c = FamilyController(api, pollInterval: null);
    await c.refresh();
    await expectLater(c.unlink(c.selected!), throwsA(isA<ApiException>()));
    expect(c.children, hasLength(1));
  });
}
