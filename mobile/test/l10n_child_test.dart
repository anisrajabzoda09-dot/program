import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/models.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/call/call_controller.dart';
import 'package:nigoh_family_parent/features/chat/chat_screen.dart';
import 'package:nigoh_family_parent/features/child/child_rules.dart';
import 'package:nigoh_family_parent/features/child/child_widgets.dart';
import 'package:nigoh_family_parent/l10n/l10n.dart';
import 'package:nigoh_family_parent/l10n/strings_child.dart';

final _placeholder = RegExp(r'\{(\w+)\}');

Set<String> _placeholders(String s) =>
    _placeholder.allMatches(s).map((m) => m[1]!).toSet();

/// Every Tajik key passed to tr() in the child / chat / call sources.
Set<String> _sourceKeys() {
  final call = RegExp(r"\btr\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)");
  final literal = RegExp(r"'((?:[^'\\]|\\.)*)'");
  final keys = <String>{};
  for (final dir in [
    'lib/features/child',
    'lib/features/chat',
    'lib/features/call',
  ]) {
    for (final f in Directory(dir).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in call.allMatches(f.readAsStringSync())) {
        keys.add(
          literal
              .allMatches(m[1]!)
              .map((l) => l[1]!)
              .join()
              .replaceAll(r"\'", "'"),
        );
      }
    }
  }
  return keys;
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _pumpChat(WidgetTester tester) async {
  final session =
      Session(
          api: NigohApi(
            client: MockClient((_) async => _json({'messages': []})),
            baseUrl: 'http://t',
          ),
        )
        ..role = 'child'
        ..api.role = 'child';
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: const MaterialApp(home: ChatScreen(childId: 7, title: 'Модар')),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _pumpNotices(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            const BedtimeNotice(
              bedtime: Bedtime(enabled: true, start: '21:00', end: '07:00'),
            ),
            const StudyNotice(
              study: StudyMode(enabled: true, start: '08:00', end: '13:00'),
            ),
            SosButton(onTriggered: () async {}),
            const ScreenTimeCard(apps: []),
            requestStatusPill('approved'),
          ],
        ),
      ),
    ),
  );
}

void main() {
  tearDown(() => appLanguage.value = 'tg');

  test(
    'every child dictionary entry has ru + en with the same placeholders',
    () {
      for (final MapEntry(:key, :value) in childStrings.entries) {
        expect(value, hasLength(2), reason: key);
        for (final t in value) {
          expect(t.trim(), isNotEmpty, reason: key);
          expect(_placeholders(t), _placeholders(key), reason: '$key → $t');
        }
      }
    },
  );

  test('every tr() key in child/chat/call sources is translated', () {
    final keys = _sourceKeys();
    expect(keys.length, greaterThan(100));
    expect(untranslatedKeys(keys), isEmpty);
    // Strings translated indirectly (weekdays, permission names, end reasons).
    expect(
      untranslatedKeys([
        ...['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш'],
        ...['Ҷойгиршавӣ', 'Огоҳиномаҳо', 'Вақти истифодаи барномаҳо'],
        ...['Экрани муҳофизат', 'Назорати барномаҳо', 'волидайн'],
      ]),
      isEmpty,
    );
    appLanguage.value = 'en';
    for (final r in CallEndReason.values) {
      expect(r.label, isNot(matches(RegExp('[ҳҷқғӣӯ]'))), reason: r.name);
    }
  });

  test('labels and SOS text follow the language', () {
    appLanguage.value = 'ru';
    expect(minutesLabel(75), '1 ч 15 мин');
    expect(weekdaysLabel([1, 2]), 'Пн, Вт');
    expect(sosMessageText(battery: 40), contains('SOS — мне нужна помощь!'));
    expect(sosMessageText(battery: 40), contains('Батарея: 40%'));
    expect(chatQuickReplies, contains('Я в пути'));
    appLanguage.value = 'en';
    expect(minutesLabel(40), '40 min');
    expect(weekdaysLabel([1, 2, 3, 4, 5, 6, 7]), 'Every day');
    expect(CallEndReason.declined.label, 'Declined');
    expect(sosMessageText(), contains('Location is not known yet.'));
    expect(chatQuickReplies, contains('On my way'));
    appLanguage.value = 'tg';
    expect(minutesLabel(60), '1 соат');
    expect(chatQuickReplies.first, 'Ман расидам');
  });

  testWidgets('chat in Russian and English', (tester) async {
    appLanguage.value = 'ru';
    await _pumpChat(tester);
    expect(find.text('Сообщений пока нет'), findsOneWidget);
    expect(find.text('Забери меня'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    appLanguage.value = 'en';
    await _pumpChat(tester);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Write the first message.'), findsOneWidget);
    expect(find.text('All good'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('child notices and SOS in Russian and English', (tester) async {
    appLanguage.value = 'ru';
    await _pumpNotices(tester);
    expect(
      find.text('Время сна — приложения закрыты до 07:00'),
      findsOneWidget,
    );
    expect(
      find.text('Учебный режим — игры и соцсети закрыты до 13:00'),
      findsOneWidget,
    );
    expect(
      find.text('В случае опасности нажмите и удерживайте'),
      findsOneWidget,
    );
    expect(find.text('одобрено'), findsOneWidget);

    appLanguage.value = 'en';
    await tester.pumpWidget(const SizedBox());
    await _pumpNotices(tester);
    expect(find.text('Bedtime — apps are locked until 07:00'), findsOneWidget);
    expect(find.text('In an emergency, press and hold'), findsOneWidget);
    expect(find.text('No apps used today yet.'), findsOneWidget);
    expect(find.text('approved'), findsOneWidget);
  });
}
