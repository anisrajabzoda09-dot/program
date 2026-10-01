import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/map_screen.dart';
import 'package:nigoh_family_parent/ui/avatar.dart';
import 'package:nigoh_family_parent/ui/theme.dart';

import 'parent_features_test.dart' show FakeServer, richSnapshot;

Future<FamilyController> _pumpMap(
  WidgetTester tester, {
  String? name,
  String? avatar,
}) async {
  // A real phone: 360 x 780 dp.
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final snap = richSnapshot();
  final child = (snap['children'] as List).first as Map<String, dynamic>;
  child['location']['updated_at'] = DateTime.now()
      .subtract(const Duration(minutes: 1, seconds: 5))
      .toUtc()
      .toIso8601String();
  if (name != null) child['name'] = name;
  if (avatar != null) child['child_avatar'] = avatar;
  final server = FakeServer(snap);
  final c = FamilyController(server.api, pollInterval: null);
  addTearDown(c.dispose);
  await tester.runAsync(c.refresh);
  await tester.pumpWidget(
    SessionScope(
      session: Session(api: server.api),
      child: MaterialApp(
        // The app theme: its FilledButton has an infinite minimum width,
        // which is what squeezed the old card text to one letter per line.
        theme: NigohTheme.light(),
        home: Scaffold(
          body: MapScreen(controller: c),
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Оила'),
              NavigationDestination(icon: Icon(Icons.map), label: 'Харита'),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return c;
}

void main() {
  testWidgets('update text stays on one line in a compact card at 360 px', (
    tester,
  ) async {
    await _pumpMap(tester);
    expect(tester.takeException(), isNull);

    final updated = find.byKey(const ValueKey('map-updated'));
    expect(updated, findsOneWidget);
    expect(find.text('Навсозӣ: 1 дақ пеш'), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: updated, matching: find.byType(RichText)),
    );
    final lineHeight = paragraph.text.style!.fontSize! * 1.6;
    expect(paragraph.size.height, lessThan(lineHeight));
    // Wide enough for the whole phrase, not a letter column.
    expect(paragraph.size.width, greaterThan(100));

    // Compact card with margins from the screen edges and the nav bar.
    final card = tester.getRect(find.byKey(const ValueKey('map-card')));
    final nav = tester.getRect(find.byType(NavigationBar));
    expect(card.left, greaterThanOrEqualTo(12));
    expect(card.right, lessThanOrEqualTo(360 - 12));
    expect(nav.top - card.bottom, greaterThanOrEqualTo(12));
    expect(card.height, lessThan(160));

    // Avatar, battery pill, refresh button, name.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('map-card')),
        matching: find.byType(AvatarView),
      ),
      findsOneWidget,
    );
    expect(find.text('Батарея 42%'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-refresh')), findsOneWidget);
    expect(find.text('Сино'), findsWidgets);

    // Top chips sit above the card and do not overlap each other.
    final history = tester.getRect(
      find.byKey(const ValueKey('history-toggle')),
    );
    final places = tester.getRect(find.byKey(const ValueKey('places-open')));
    expect(history.overlaps(places), isFalse);
    expect(history.bottom, lessThan(card.top));
  });

  testWidgets('long name is ellipsized and the marker shows the photo', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      name: 'Абдурраҳмонзода Муҳаммадсаид Fарҳодович',
      avatar: '/static/avatars/7.jpg',
    );
    expect(tester.takeException(), isNull);
    final updated = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('map-updated')),
        matching: find.byType(RichText),
      ),
    );
    expect(updated.size.height, lessThan(12.5 * 1.6));
    final marker = find.byKey(const ValueKey('child-marker'));
    expect(marker, findsOneWidget);
    final avatar = tester.widget<AvatarView>(
      find.descendant(of: marker, matching: find.byType(AvatarView)),
    );
    expect(avatar.url, 'https://nigohfamily.qobus.tj/static/avatars/7.jpg');
    await tester.pumpWidget(const SizedBox());
  });
}
