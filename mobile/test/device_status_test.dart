import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/home_target.dart';
import 'package:nigoh_family_parent/core/models.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';

import 'family_controller_test.dart' show snapshotJson;
import 'parent_features_test.dart' show FakeServer;

String _iso(DateTime t) => t.toUtc().toIso8601String();

Map<String, dynamic> _child(
  int id,
  String name, {
  int? battery,
  DateTime? seen,
  int? locationBattery,
}) {
  final c = Map<String, dynamic>.from(
    (snapshotJson()['children'] as List).first as Map,
  );
  c['id'] = id;
  c['name'] = name;
  if (battery != null) c['battery_level'] = battery;
  c['location'] = seen == null
      ? null
      : {
          'latitude': 38.55,
          'longitude': 68.78,
          'battery_level': locationBattery,
          'updated_at': _iso(seen),
        };
  return c;
}

void main() {
  final now = DateTime.now();

  test('battery falls back to the location; attention order', () {
    final ok = FamilyChild.fromJson(_child(1, 'А', battery: 80, seen: now));
    final low = FamilyChild.fromJson(
      _child(2, 'Б', seen: now, locationBattery: 9),
    );
    final off = FamilyChild.fromJson(
      _child(3, 'В', battery: 70, seen: now.subtract(const Duration(hours: 1))),
    );
    final never = FamilyChild.fromJson(_child(4, 'Г'));
    expect(batteryOf(low), 9);
    expect(isLowBattery(low), isTrue);
    expect(isLowBattery(ok), isFalse);
    expect(isOfflineChild(off), isTrue);
    expect(isOfflineChild(never), isTrue);
    expect(
      isOfflineChild(
        FamilyChild.fromJson(
          _child(5, 'Д', seen: now.subtract(const Duration(minutes: 19))),
        ),
      ),
      isFalse,
    );
    expect(attentionRank(ok), 3);
    expect(attentionRank(low), 1);
    expect(attentionRank(off), 2);
  });

  testWidgets('low battery and offline pills, internet row, call button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeServer({
      'children': [
        _child(1, 'Сино', battery: 80, seen: now),
        _child(
          2,
          'Алӣ',
          battery: 9,
          seen: now.subtract(const Duration(hours: 2)),
        ),
      ],
    });
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

    expect(find.byKey(const ValueKey('battery-low-2')), findsOneWidget);
    expect(find.text('Батарея кам: 9%'), findsOneWidget);
    expect(find.byKey(const ValueKey('battery-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('offline-2')), findsOneWidget);
    expect(find.text('Офлайн — 2 соат пеш'), findsOneWidget);
    expect(find.byKey(const ValueKey('offline-1')), findsNothing);
    expect(find.text('Интернет: пайваст'), findsOneWidget);
    expect(find.text('Интернет: пайваст нест'), findsOneWidget);
    expect(find.byKey(const ValueKey('device-alerts')), findsOneWidget);
    expect(find.byKey(const ValueKey('call-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('call-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('study-1')), findsOneWidget);

    // Child needing attention is listed first.
    final first = tester.getTopLeft(find.byKey(const ValueKey('child-2')));
    final second = tester.getTopLeft(find.byKey(const ValueKey('child-1')));
    expect(first.dy, lessThan(second.dy));

    final call = tester.widget<IconButton>(
      find.byKey(const ValueKey('call-1')),
    );
    expect(call.tooltip, 'Занг');
    expect(call.onPressed, isNotNull);
  });

  testWidgets('notification target selects the child and the map tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeServer({
      'children': [
        _child(1, 'Сино', battery: 80, seen: now),
        _child(2, 'Алӣ', battery: 50, seen: now),
      ],
    });
    final c = FamilyController(server.api, pollInterval: null);
    addTearDown(c.dispose);
    await tester.runAsync(c.refresh);
    await tester.pumpWidget(
      SessionScope(
        session: Session(api: server.api),
        child: MaterialApp(home: ParentHome(controller: c)),
      ),
    );
    await tester.pump();
    homeTarget.value = const HomeTarget('map', childId: 2);
    await tester.pump();
    expect(homeTarget.value, isNull);
    expect(c.selectedChildId, 2);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    homeTarget.value = const HomeTarget('overview');
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
