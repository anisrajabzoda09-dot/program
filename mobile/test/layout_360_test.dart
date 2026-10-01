import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/apps_screen.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';
import 'package:nigoh_family_parent/ui/avatar.dart';
import 'package:nigoh_family_parent/ui/theme.dart';

import 'parent_features_test.dart' show FakeServer, richSnapshot;

const _longChild = 'Абдурраҳмонзода Муҳаммадсаид Фарҳодович';
const _longApp = 'Очень длинное название приложения для детей 2026 Pro Max';

Map<String, dynamic> _snapshot() {
  final snap = richSnapshot(
    pending: 3,
    unread: 12,
    bedtime: {'enabled': true, 'start': '21:30', 'end': '07:00'},
  );
  final children = snap['children'] as List;
  final first = children.first as Map<String, dynamic>;
  first['name'] = _longChild;
  first['battery_level'] = 9;
  first['child_avatar'] = '/static/avatars/7.jpg';
  final apps = first['apps'] as List;
  (apps.first as Map<String, dynamic>)['app_name'] = _longApp;
  final second = Map<String, dynamic>.from(first)
    ..['id'] = 8
    ..['name'] = 'Алӣ'
    ..remove('child_avatar');
  children.add(second);
  return snap;
}

Future<FamilyController> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final server = FakeServer(_snapshot());
  final c = FamilyController(server.api, pollInterval: null);
  addTearDown(c.dispose);
  await tester.runAsync(c.refresh);
  final session = Session(api: server.api)
    ..user = {'full_name': 'Модар Каримова', 'avatar': '/static/avatars/1.jpg'};
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: MaterialApp(
        theme: NigohTheme.light(),
        home: ParentHome(controller: c),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void _expectInside(WidgetTester tester, Finder finder) {
  for (final element in finder.evaluate()) {
    final box = element.renderObject! as RenderBox;
    if (!box.hasSize || !box.attached) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    expect(rect.left, greaterThanOrEqualTo(-0.5));
    expect(rect.right, lessThanOrEqualTo(360.5));
  }
}

void main() {
  testWidgets('overview at 360 px: avatars, no overflow, long names', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(tester.takeException(), isNull);

    // Parent greeting with the photo, child cards with theirs.
    final greeting = find.byKey(const ValueKey('greeting'));
    expect(greeting, findsOneWidget);
    final parentAvatar = tester.widget<AvatarView>(
      find.descendant(of: greeting, matching: find.byType(AvatarView)),
    );
    expect(parentAvatar.url, endsWith('/static/avatars/1.jpg'));
    expect(find.text('Салом, Модар!'), findsOneWidget);
    expect(find.text('Фарзандон'), findsOneWidget);

    final card = find.byKey(const ValueKey('child-7'));
    final cardAvatar = tester.widget<AvatarView>(
      find.descendant(of: card, matching: find.byType(AvatarView)).first,
    );
    expect(cardAvatar.url, endsWith('/static/avatars/7.jpg'));
    _expectInside(tester, find.byType(Card));
    _expectInside(tester, find.text(_longChild));

    // Bottom navigation: every label fits in its slot.
    for (final label in ['Оила', 'Барномаҳо', 'Харита', 'Чат', 'Танзимот']) {
      final text = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      expect(text, findsWidgets);
      expect(tester.getSize(text.first).width, lessThanOrEqualTo(360 / 5));
    }

    // Scroll through the whole list: still nothing overflows.
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('apps tab and map tab at 360 px with long names', (tester) async {
    await _pumpHome(tester);
    await tester.tap(find.text('Барномаҳо').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(_longApp),
      300,
      scrollable: find
          .descendant(
            of: find.byType(AppsScreen),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
    expect(find.text(_longApp), findsWidgets);
    _expectInside(tester, find.text(_longApp));

    await tester.tap(find.text('Харита').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('map-card')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
