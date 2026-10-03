import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/map_screen.dart';
import 'package:nigoh_family_parent/ui/avatar.dart';
import 'package:nigoh_family_parent/ui/theme.dart';

import 'parent_features_test.dart' show FakeServer, richSnapshot;

/// Pumps the map tab the way a phone shows it: real safe-area insets, the
/// nav bar under it and the app theme.
Future<FamilyController> _pumpMap(
  WidgetTester tester, {
  String? name,
  String? avatar,
  Size size = const Size(360, 780),
  double textScale = 1,
  bool dark = false,
  bool withPlace = false,
  String? placesError,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 30, bottom: 48);
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
  if (withPlace) {
    server.getResponses['/places'] = {
      'places': [
        {
          'id': 1,
          // A long name: the status label must shrink, not grow the card.
          'name': 'Мактаби миёнаи рақами 55-и шаҳри Душанбе',
          'latitude': 38.5598,
          'longitude': 68.787,
          'radius_meters': 200,
        },
      ],
    };
  }
  final c = FamilyController(server.api, pollInterval: null);
  addTearDown(c.dispose);
  await tester.runAsync(c.refresh);
  if (withPlace) await tester.runAsync(() => c.loadPlaces(c.selected!.id));
  if (placesError != null) c.placesError = placesError;
  await tester.pumpWidget(
    SessionScope(
      session: Session(api: server.api),
      child: MaterialApp(
        // The app theme: its FilledButton has an infinite minimum width,
        // which is what squeezed the old card text to one letter per line.
        theme: dark ? NigohTheme.dark() : NigohTheme.light(),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
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
  await tester.pump(const Duration(milliseconds: 400));
  return c;
}

/// The floating panel at the bottom: everything that paints over the map.
double _overlayHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('map-card-area'))).height;

void main() {
  testWidgets('update text stays on one line in a compact card at 360 px', (
    tester,
  ) async {
    await _pumpMap(tester);
    expect(tester.takeException(), isNull);

    final updated = find.byKey(const ValueKey('map-updated'));
    expect(updated, findsOneWidget);
    expect(find.text('Ҷойи охирин: 1 дақ пеш'), findsOneWidget);
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
    expect(card.height, lessThan(200));

    // Avatar, battery, refresh button, name and the OSM credit in the card.
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
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

    // Top chips sit above the card and do not overlap each other.
    final history = tester.getRect(
      find.byKey(const ValueKey('history-toggle')),
    );
    final places = tester.getRect(find.byKey(const ValueKey('places-open')));
    expect(history.overlaps(places), isFalse);
    expect(history.bottom, lessThan(card.top));
    // The long-press hint: adding a safe place is otherwise invisible.
    expect(find.byKey(const ValueKey('map-hint')), findsOneWidget);
  });

  // The phone bug: «як панели сиёх ними экранро мепушонад» — the floating
  // card grew with the system font scale (and with a long place name or an
  // error line) until it covered half the map.
  group('the bottom card never covers the map', () {
    const cases = <(String, Size, double)>[
      ('phone', Size(360, 780), 1),
      ('phone, large system font', Size(360, 780), 1.3),
      ('small phone, largest system font', Size(320, 640), 2),
      ('accessibility font scale', Size(360, 780), 3),
      ('tablet / desktop window', Size(1280, 800), 1),
    ];

    for (final (label, size, scale) in cases) {
      testWidgets('$label: under 45 % of the screen', (tester) async {
        await _pumpMap(
          tester,
          size: size,
          textScale: scale,
          dark: true,
          withPlace: true,
          name: 'Абдурраҳмонзода Муҳаммадсаид Фарҳодович',
          placesError: 'Пайвасти интернет нест. Аз нав кӯшиш кунед.',
        );
        expect(tester.takeException(), isNull);
        // The map itself stays full-bleed inside the tab.
        final map = tester.getRect(find.byType(MapScreen));
        expect(map.width, size.width);
        final overlay = _overlayHeight(tester);
        expect(
          overlay,
          lessThan(map.height * .45),
          reason: 'bottom panel $overlay dp of ${map.height} dp',
        );
        // And the card still hugs the bottom of the map.
        final card = tester.getRect(find.byKey(const ValueKey('map-card')));
        expect(card.bottom, greaterThan(map.top + map.height * .55));
      });
    }
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
