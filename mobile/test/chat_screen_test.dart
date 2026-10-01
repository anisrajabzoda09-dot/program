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
}) => {
  'id': id,
  'child_id': 7,
  'sender_role': role,
  'sender_name': role == 'parent' ? 'Модар' : 'Алӣ',
  'message_type': type,
  'content': content,
  'created_at': '2026-10-01 08:30:00',
};

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> pumpChat(WidgetTester tester, MockClient client) async {
  final session =
      Session(
          api: NigohApi(client: client, baseUrl: 'http://t'),
        )
        ..role = 'child'
        ..api.role = 'child';
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: const MaterialApp(home: ChatScreen(childId: 7, title: 'Модар')),
    ),
  );
  await tester.pump(); // post-frame load
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('renders messages and call chips from the server', (
    tester,
  ) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      expect(req.method, 'GET');
      expect(req.url.path, '/api/mobile/v2/children/7/chat');
      return json({
        'messages': [
          msg(1, 'parent', 'Салом, писарам'),
          msg(2, 'child', 'Салом, модар'),
          msg(3, 'parent', chatCallText, type: 'call'),
        ],
      });
    });
    await pumpChat(tester, client);
    expect(find.text('Салом, писарам'), findsOneWidget);
    expect(find.text('Салом, модар'), findsOneWidget);
    expect(find.textContaining('хоҳиш дорад, ки занг занед'), findsOneWidget);
    expect(find.byIcon(Icons.phone_in_talk_rounded), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('empty chat shows the empty state', (tester) async {
    await pumpChat(tester, MockClient((_) async => json({'messages': []})));
    expect(find.text('Ҳоло паём нест'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('load error is shown with retry', (tester) async {
    var fail = true;
    final client = MockClient((req) async {
      if (fail) return json({'detail': 'Дастрасӣ нест'}, 403);
      return json({
        'messages': [msg(1, 'parent', 'Тайёр')],
      });
    });
    await pumpChat(tester, client);
    expect(find.text('Паёмҳо бор нашуданд'), findsOneWidget);
    expect(find.text('Дастрасӣ нест'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Аз нав кӯшиш'));
    await tester.pumpAndSettle();
    expect(find.text('Тайёр'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('sending posts the right body and shows the message', (
    tester,
  ) async {
    Map<String, dynamic>? posted;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      if (req.method == 'POST') {
        posted = jsonDecode(req.body) as Map<String, dynamic>;
        return json({
          'status': 'success',
          'message': msg(10, 'child', 'Ман дар хонаам'),
        });
      }
      return json({'messages': []});
    });
    await pumpChat(tester, client);
    await tester.enterText(find.byType(TextField), '  Ман дар хонаам ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(posted, {
      'content': 'Ман дар хонаам',
      'message_type': 'text',
      'duration_sec': 0,
    });
    expect(find.text('Ман дар хонаам'), findsOneWidget);
    expect(find.text('Фиристода нашуд'), findsNothing);
    await unmount(tester);
  });

  testWidgets('send button is disabled while the input is empty', (
    tester,
  ) async {
    await pumpChat(tester, MockClient((_) async => json({'messages': []})));
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send_rounded),
    );
    expect(button.onPressed, isNull);
    await unmount(tester);
  });

  testWidgets('failed send shows retry, retry delivers it', (tester) async {
    var failPost = true;
    var posts = 0;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      if (req.method == 'POST') {
        posts++;
        if (failPost) return json({'detail': 'Сервер банд аст'}, 500);
        return json({
          'status': 'success',
          'message': msg(11, 'child', 'Салом'),
        });
      }
      return json({'messages': []});
    });
    await pumpChat(tester, client);
    await tester.enterText(find.byType(TextField), 'Салом');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Фиристода нашуд'), findsOneWidget);
    expect(find.byTooltip('Аз нав фиристодан'), findsOneWidget);
    expect(find.text('Сервер банд аст'), findsOneWidget); // snackbar
    failPost = false;
    await tester.tap(find.byTooltip('Аз нав фиристодан'));
    await tester.pumpAndSettle();
    expect(posts, 2);
    expect(find.text('Фиристода нашуд'), findsNothing);
    expect(find.text('Салом'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('call button sends a call message', (tester) async {
    Map<String, dynamic>? posted;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/read')) return json({'status': 'ok'});
      if (req.method == 'POST') {
        posted = jsonDecode(req.body) as Map<String, dynamic>;
        return json({
          'status': 'success',
          'message': msg(12, 'child', chatCallText, type: 'call'),
        });
      }
      return json({'messages': []});
    });
    await pumpChat(tester, client);
    await tester.tap(find.byIcon(Icons.phone_rounded));
    await tester.pumpAndSettle();
    expect(posted?['message_type'], 'call');
    expect(posted?['content'], chatCallText);
    expect(find.text('Хоҳиши занг фиристода шуд'), findsOneWidget);
    expect(find.textContaining('Шумо хоҳиши занг фиристодед'), findsOneWidget);
    await unmount(tester);
  });
}
