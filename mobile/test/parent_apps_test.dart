import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/features/parent/apps_screen.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';

import 'family_controller_test.dart' show snapshotJson, jsonResponse;

void main() {
  Future<FamilyController> pumpApps(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final api = NigohApi(client: MockClient(handler));
    final c = FamilyController(api, pollInterval: null);
    await tester.runAsync(c.refresh);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppsScreen(controller: c)),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('shows the app cards for the child', (tester) async {
    await pumpApps(tester, (_) async => jsonResponse(snapshotJson()));
    expect(find.text('Roblox'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Ҳолати танаффус'), findsOneWidget);
    expect(find.text('08:00–13:00'), findsOneWidget);
  });

  testWidgets('toggling block calls PUT with is_blocked', (tester) async {
    final puts = <Map<String, dynamic>>[];
    final c = await pumpApps(tester, (request) async {
      if (request.method == 'PUT') {
        puts.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse({'ok': true});
      }
      return jsonResponse(snapshotJson());
    });
    await tester.tap(find.byKey(const ValueKey('block-com.roblox.client')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(puts, [
      {'is_blocked': true},
    ]);
    expect(c.selected!.apps.first.blocked, isTrue);
  });

  testWidgets('failed toggle rolls back and shows the server message', (
    tester,
  ) async {
    final c = await pumpApps(tester, (request) async {
      if (request.method == 'PUT') {
        return jsonResponse({'detail': 'Сервер банд аст'}, 503);
      }
      return jsonResponse(snapshotJson());
    });
    await tester.tap(find.byKey(const ValueKey('block-com.roblox.client')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Сервер банд аст'), findsOneWidget);
    expect(c.selected!.apps.first.blocked, isFalse);
    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('block-com.roblox.client')),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('no apps yet shows the explanation and refresh', (tester) async {
    await pumpApps(tester, (_) async => jsonResponse(snapshotJson(apps: [])));
    expect(find.text('Рӯйхати барномаҳо ҳоло нест'), findsOneWidget);
    expect(find.textContaining('як дақиқа'), findsOneWidget);
    expect(find.text('Навсозӣ'), findsOneWidget);
  });

  Future<void> pumpHome(WidgetTester tester, Map<String, dynamic> snap) async {
    final api = NigohApi(
      client: MockClient((_) async => jsonResponse(snap)),
    );
    final c = FamilyController(api, pollInterval: null);
    addTearDown(c.dispose);
    await tester.runAsync(c.refresh);
    await tester.pumpWidget(
      SessionScope(
        session: Session(api: api),
        child: MaterialApp(home: ParentHome(controller: c)),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('home shows a card per child', (tester) async {
    await pumpHome(tester, snapshotJson());
    expect(find.text('Сино'), findsOneWidget);
    expect(find.text('Офлайн'), findsOneWidget);
    expect(find.text('Илова кардани фарзанд'), findsOneWidget);
  });

  testWidgets('home without children offers to add one', (tester) async {
    await pumpHome(tester, {'children': []});
    expect(find.text('Ҳоло фарзанд пайваст нашудааст'), findsOneWidget);
    expect(find.text('Илова кардани фарзанд'), findsOneWidget);
  });
}
