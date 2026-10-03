import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/apps_screen.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';
import 'package:nigoh_family_parent/features/parent/parent_logic.dart';
import 'package:nigoh_family_parent/l10n/l10n.dart';
import 'package:nigoh_family_parent/l10n/strings_parent.dart';

import 'family_controller_test.dart' show snapshotJson, jsonResponse;

final _placeholder = RegExp(r'\{\w+\}');

List<String> _placeholders(String s) =>
    _placeholder.allMatches(s).map((m) => m[0]!).toList()..sort();

/// Every literal key passed to tr('…') in lib/features/parent.
Set<String> _parentKeys() {
  final keys = <String>{};
  final call = RegExp(r"\btr\(\s*'((?:[^'\\]|\\.)*)'");
  for (final file in Directory(
    'lib/features/parent',
  ).listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    for (final m in call.allMatches(file.readAsStringSync())) {
      keys.add(m[1]!.replaceAll(r"\'", "'"));
    }
  }
  return keys;
}

void main() {
  tearDown(() => appLanguage.value = 'tg');

  group('parent dictionary', () {
    test('every entry has non-empty ru/en with the same placeholders', () {
      for (final MapEntry(:key, :value) in parentStrings.entries) {
        expect(value, hasLength(2), reason: key);
        for (final t in value) {
          expect(t.trim(), isNotEmpty, reason: key);
          expect(_placeholders(t), _placeholders(key), reason: '$key → $t');
        }
      }
    });

    test('every tr() key in lib/features/parent is translated', () {
      final keys = _parentKeys();
      expect(keys.length, greaterThan(150));
      expect(untranslatedKeys(keys).toList(), isEmpty);
    });

    test('weekday chips and category labels are translated', () {
      for (final d in weekdayShort) {
        expect(parentStrings.containsKey(d), isTrue, reason: d);
      }
      for (final c in AppCategory.values) {
        expect(parentStrings.containsKey(c.label), isTrue, reason: c.label);
        expect(
          parentStrings.containsKey(c.pluralLower),
          isTrue,
          reason: c.pluralLower,
        );
      }
    });

    test('helpers follow the language', () {
      expect(limitLabelText(90), '1с 30д');
      appLanguage.value = 'ru';
      expect(limitLabelText(90), '1ч 30м');
      expect(tr(weekdayShort.first), 'Пн');
      appLanguage.value = 'en';
      expect(limitLabelText(0), 'No limit');
      expect(formatMinutes(40), '40 min');
      expect(tr(weekdayShort.last), 'Sun');
    });
  });

  Future<void> pumpHome(WidgetTester tester) async {
    final api = NigohApi(
      client: MockClient((_) async => jsonResponse(snapshotJson())),
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

  Future<void> pumpApps(WidgetTester tester) async {
    final api = NigohApi(
      client: MockClient((_) async => jsonResponse(snapshotJson())),
    );
    final c = FamilyController(api, pollInterval: null);
    addTearDown(c.dispose);
    await tester.runAsync(c.refresh);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppsScreen(controller: c)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('parent home in Russian', (tester) async {
    appLanguage.value = 'ru';
    await pumpHome(tester);
    expect(find.text('Семья'), findsWidgets);
    expect(find.text('Приложения'), findsWidgets);
    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Дети'), findsOneWidget);
    expect(find.text('Офлайн'), findsOneWidget);
    expect(find.text('Оила'), findsNothing);
  });

  testWidgets('parent home in English', (tester) async {
    appLanguage.value = 'en';
    await pumpHome(tester);
    expect(find.text('Family'), findsWidgets);
    expect(find.text('Map'), findsWidgets);
    expect(find.text('Children'), findsOneWidget);
    expect(find.text('Screen time'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Барномаҳо'), findsNothing);
  });

  testWidgets('apps screen in Russian and English', (tester) async {
    appLanguage.value = 'ru';
    await pumpApps(tester);
    expect(find.text('Пауза'), findsOneWidget);
    expect(find.text('Заблокировать все'), findsOneWidget);
    expect(find.text('Поиск приложения'), findsOneWidget);
    // v2.17.0 copy: the group label, the mode tiles and their values.
    expect(find.text('Режимы и отчёт'), findsOneWidget);
    expect(find.text('Отчёт'), findsOneWidget);
    expect(find.text('Последние 7 дней'), findsOneWidget);
    expect(find.text('Учебный режим'), findsOneWidget);
    expect(find.text('выключено'), findsWidgets);

    appLanguage.value = 'en';
    await pumpApps(tester);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Block all'), findsOneWidget);
    expect(find.text('Search apps'), findsOneWidget);
    expect(find.text('Modes and report'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('Study mode'), findsOneWidget);
    expect(find.text('off'), findsWidgets);
  });
}
