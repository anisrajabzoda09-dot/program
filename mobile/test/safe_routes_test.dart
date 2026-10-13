import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/models.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/safe_routes_sheet.dart';
import 'package:nigoh_family_parent/ui/theme.dart';

Map<String, dynamic> routeJson({String status = 'idle'}) => {
  'id': 9,
  'name': 'Хона — мактаб',
  'start_place_id': 1,
  'end_place_id': 2,
  'start_place': {
    'id': 1,
    'name': 'Хона',
    'latitude': 38.55,
    'longitude': 68.75,
  },
  'end_place': {
    'id': 2,
    'name': 'Мактаб',
    'latitude': 38.55,
    'longitude': 68.80,
  },
  'start_time': '07:30',
  'arrive_by': '08:00',
  'weekdays': [1, 2, 3, 4, 5],
  'corridor_meters': 300,
  'enabled': true,
  'today_status': status,
};

void main() {
  test('safe route parses real endpoints and pending check-in', () {
    final route = SafeRoute.fromJson(routeJson(status: 'pending'));
    expect(route.startName, 'Хона');
    expect(route.endName, 'Мактаб');
    expect(route.weekdays, [1, 2, 3, 4, 5]);
    expect(route.needsCheckIn, isTrue);
  });

  testWidgets('route form fits a compact phone and can save', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 720);
    addTearDown(tester.view.reset);
    http.Request? saved;
    final api = NigohApi(
      client: MockClient((request) async {
        if (request.method == 'POST') saved = request;
        if (request.method == 'GET' &&
            request.url.path.endsWith('/safe-routes')) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'routes': [routeJson()],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'status': 'success', 'route': routeJson()}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final controller = FamilyController(api, pollInterval: null);
    addTearDown(controller.dispose);
    const places = [
      SafePlace(
        id: 1,
        name: 'Хона',
        latitude: 38.55,
        longitude: 68.75,
        radiusMeters: 150,
      ),
      SafePlace(
        id: 2,
        name: 'Мактаб',
        latitude: 38.55,
        longitude: 68.80,
        radiusMeters: 150,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: NigohTheme.light(),
        home: Scaffold(
          body: AddSafeRouteSheet(
            controller: controller,
            childId: 7,
            places: places,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final save = find.byKey(const ValueKey('safe-route-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    final body = jsonDecode(saved!.body) as Map<String, dynamic>;
    expect(body['start_place_id'], 1);
    expect(body['end_place_id'], 2);
    expect(body['corridor_meters'], 300);
  });
}
