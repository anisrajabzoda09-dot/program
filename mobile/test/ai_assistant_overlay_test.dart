import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/ai_assistant_overlay.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'family_controller_test.dart' show jsonResponse, snapshotJson;

void main() {
  testWidgets('floating AI moves, answers and applies an approved app rule', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final calls = <http.Request>[];
    final api = NigohApi(
      client: MockClient((request) async {
        calls.add(request);
        if (request.url.path.endsWith('/places')) {
          return jsonResponse({'places': []});
        }
        if (request.url.path.endsWith('/ai/rules/preview')) {
          return jsonResponse({
            'status': 'success',
            'proposal': {
              'summary': 'Roblox баста мешавад.',
              'actions': [
                {
                  'package_name': 'com.roblox.client',
                  'is_blocked': true,
                  'reason': 'Дархости волидайн',
                },
              ],
            },
          });
        }
        if (request.url.path.endsWith('/ai/help')) {
          return jsonResponse({
            'answer': 'Ман метавонам қоидаҳоро шарҳ диҳам.',
          });
        }
        if (request.method == 'PUT') return jsonResponse({'status': 'success'});
        return jsonResponse(snapshotJson());
      }),
    );
    final controller = FamilyController(api, pollInterval: null);
    addTearDown(controller.dispose);
    await tester.runAsync(controller.refresh);
    final session = Session(api: api)
      ..user = {'full_name': 'Модар', 'role': 'parent'};
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) =>
              AiAssistantPortal(navigatorKey: navigatorKey, child: child!),
          home: ParentHome(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bubble = find.byKey(const ValueKey('nigoh-ai-bubble'));
    expect(bubble, findsOneWidget);
    final before = tester.getCenter(bubble);
    await tester.drag(bubble, const Offset(-90, -110));
    await tester.pumpAndSettle();
    final after = tester.getCenter(bubble);
    expect(after.dx, lessThan(before.dx - 40));
    expect(after.dy, lessThan(before.dy - 40));

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Экрани дигар')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Экрани дигар'), findsOneWidget);
    expect(bubble, findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    await tester.tap(bubble);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-chat-input')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('ai-chat-input')),
      'Roblox-ро банд кун',
    );
    await tester.tap(find.byKey(const ValueKey('ai-chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Roblox баста мешавад.'), findsOneWidget);
    expect(controller.selected!.apps.first.blocked, isFalse);

    await tester.tap(find.byKey(const ValueKey('ai-chat-apply')));
    await tester.pumpAndSettle();
    expect(controller.selected!.apps.first.blocked, isTrue);
    final update = calls.lastWhere((request) => request.method == 'PUT');
    expect(update.url.path, '/api/mobile/v2/children/7/apps/com.roblox.client');
    expect(jsonDecode(update.body), {'is_blocked': true});

    await tester.enterText(
      find.byKey(const ValueKey('ai-chat-input')),
      'Лимит чӣ тавр кор мекунад?',
    );
    await tester.tap(find.byKey(const ValueKey('ai-chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Ман метавонам қоидаҳоро шарҳ диҳам.'), findsOneWidget);
    expect(
      calls.any((request) => request.url.path.endsWith('/ai/help')),
      isTrue,
    );
  });
}
