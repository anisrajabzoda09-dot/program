import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/chat/chat_screen.dart';

Map<String, dynamic> msg(
  int id,
  String role,
  String content, {
  String type = 'text',
  bool read = false,
}) => {
  'id': id,
  'child_id': 7,
  'sender_role': role,
  'sender_name': role == 'parent' ? 'Модар' : 'Алӣ',
  'message_type': type,
  'content': content,
  'created_at': '2026-10-01 08:30:00',
  'is_read': read,
};

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> pumpChat(
  WidgetTester tester,
  MockClient client, {
  String role = 'child',
}) async {
  final session =
      Session(
          api: NigohApi(client: client, baseUrl: 'http://t'),
        )
        ..role = role
        ..api.role = role;
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: const MaterialApp(home: ChatScreen(childId: 7, title: 'Модар')),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  testWidgets('marks read on load and when the other side writes', (
    tester,
  ) async {
    var reads = 0;
    final messages = [msg(1, 'parent', 'Салом')];
    final client = MockClient((req) async {
      if (req.url.path == '/api/mobile/v2/children/7/chat/read') {
        expect(req.method, 'POST');
        reads++;
        return json({'status': 'success'});
      }
      final after = int.tryParse(req.url.queryParameters['after_id'] ?? '0');
      return json({
        'messages': messages.where((m) => (m['id'] as int) > after!).toList(),
      });
    });
    await pumpChat(tester, client);
    expect(reads, 1);
    // A poll with nothing new does not mark again.
    await tester.pump(ChatScreen.pollInterval);
    await tester.pumpAndSettle();
    expect(reads, 1);
    messages.add(msg(2, 'parent', 'Куҷоӣ?'));
    await tester.pump(ChatScreen.pollInterval);
    await tester.pumpAndSettle();
    expect(find.text('Куҷоӣ?'), findsOneWidget);
    expect(reads, 2);
    await unmount(tester);
  });

  testWidgets('«Хонда шуд» under my last message once it is read', (
    tester,
  ) async {
    var read = false;
    final afterIds = <String?>[];
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      afterIds.add(req.url.queryParameters['after_id']);
      return json({
        'messages': [
          msg(1, 'child', 'Аввал', read: true),
          msg(2, 'child', 'Охирон', read: read),
        ],
      });
    });
    await pumpChat(tester, client);
    expect(find.textContaining('Хонда шуд'), findsNothing);
    read = true;
    await tester.pump(ChatScreen.pollInterval);
    await tester.pumpAndSettle();
    // The poll re-fetched my unread message to refresh its flag.
    expect(afterIds.last, '1');
    expect(find.textContaining('Хонда шуд'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('urgent message is a red alert bubble (parent view)', (
    tester,
  ) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      return json({
        'messages': [
          msg(
            5,
            'child',
            'SOS — ба кӯмак ниёз дорам!\nБатарея: 20%',
            type: 'urgent',
          ),
        ],
      });
    });
    await pumpChat(tester, client, role: 'parent');
    expect(find.byKey(const ValueKey('urgent-bubble')), findsOneWidget);
    expect(find.text('Алӣ SOS фиристод'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    // Parents get no check-in chips.
    expect(find.text('Ман расидам'), findsNothing);
    await unmount(tester);
  });

  testWidgets('child quick check-in chip sends with one tap', (tester) async {
    Map<String, dynamic>? posted;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      if (req.method == 'POST') {
        posted = jsonDecode(req.body) as Map<String, dynamic>;
        return json({
          'status': 'success',
          'message': msg(9, 'child', posted!['content'] as String),
        });
      }
      return json({'messages': []});
    });
    await pumpChat(tester, client);
    for (final text in chatQuickReplies) {
      expect(find.widgetWithText(ActionChip, text), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ActionChip, 'Ман расидам'));
    await tester.pumpAndSettle();
    expect(posted, {
      'content': 'Ман расидам',
      'message_type': 'text',
      'duration_sec': 0,
    });
    // Shown as a bubble (the chip text appears twice: chip + bubble).
    expect(find.text('Ман расидам'), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('new messages slide in and the day separator says «Имрӯз»', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    String stamp(DateTime t) =>
        '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:00';
    final now = DateTime.now().toUtc();
    final messages = [msg(1, 'parent', 'Салом')..['created_at'] = stamp(now)];
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      final after = int.tryParse(req.url.queryParameters['after_id'] ?? '0')!;
      return json({
        'messages': messages.where((m) => (m['id'] as int) > after).toList(),
      });
    });
    await pumpChat(tester, client);
    expect(find.text('Имрӯз'), findsOneWidget);
    expect(tester.takeException(), isNull);

    messages.add(msg(2, 'parent', 'Куҷоӣ?')..['created_at'] = stamp(now));
    await tester.pump(ChatScreen.pollInterval);
    await tester.pump(const Duration(milliseconds: 16));
    // Still fading/sliding in.
    final fade = tester.widgetList<Opacity>(
      find.ancestor(of: find.text('Куҷоӣ?'), matching: find.byType(Opacity)),
    );
    expect(fade.any((o) => o.opacity < 1), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Куҷоӣ?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('chat fits a 360 px phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      return json({
        'messages': [
          msg(1, 'parent', 'Салом, писарам, имрӯз чӣ хел буд дар мактаб?'),
          msg(2, 'child', 'Ҳама хуб аст, ман дар роҳам ба хона'),
          msg(3, 'child', 'SOS — ба кӯмак ниёз дорам!', type: 'urgent'),
        ],
      });
    });
    await pumpChat(tester, client);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('urgent-bubble')), findsOneWidget);
    // The quick-reply row is scrollable, so only the first chips are built.
    expect(
      find.widgetWithText(ActionChip, chatQuickReplies.first),
      findsOneWidget,
    );
    await unmount(tester);
  });
}
