import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/apps_screen.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';
import 'package:nigoh_family_parent/features/parent/parent_sheets.dart';
import 'package:nigoh_family_parent/features/parent/places_sheets.dart';
import 'package:nigoh_family_parent/features/parent/requests_screen.dart';
import 'package:nigoh_family_parent/features/parent/study_sheet.dart';
import 'package:nigoh_family_parent/features/parent/weekly_report.dart';
import 'package:nigoh_family_parent/ui/theme.dart';
import 'package:nigoh_family_parent/ui/widgets.dart';

import 'parent_features_test.dart' show FakeServer, richSnapshot;

/// v2.17.0: every parent screen says what it is for, groups its controls
/// under a label, puts a unit on every number and tells the parent what to
/// do next when there is nothing to show — at phone and desktop sizes.
const phone = Size(360, 780);
const desktop = Size(1280, 800);

Future<FamilyController> _controller(
  WidgetTester tester, {
  Map<String, dynamic>? snap,
  bool withPlace = false,
  bool withUsage = false,
}) async {
  final server = FakeServer(
    snap ??
        richSnapshot(
          pending: 2,
          bedtime: const {'enabled': true, 'start': '21:30', 'end': '07:00'},
        ),
  );
  if (withUsage) {
    server.getResponses['/usage'] = {
      'days': [
        for (var i = 0; i < 7; i++)
          {
            'date': DateTime(
              2026,
              10,
              1,
            ).add(Duration(days: i)).toIso8601String().substring(0, 10),
            'minutes': 30 + i * 10,
            'top': [
              {
                'package_name': 'com.app\$i',
                'app_name': 'Барнома \$i',
                'minutes': 30 + i * 10,
              },
            ],
          },
      ],
    };
  }
  if (withPlace) {
    server.getResponses['/places'] = {
      'places': [
        {
          'id': 1,
          'name': 'Хона',
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
  return c;
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = phone,
  bool noMotion = false,
  required FamilyController controller,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SessionScope(
      session: Session(api: controller.api),
      child: MaterialApp(
        theme: NigohTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: noMotion),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the first list until [finder] is built — the app cards sit below
/// the fold on a phone.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in <(String, Size)>[
    ('phone', phone),
    ('desktop', desktop),
  ]) {
    group('$label ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('overview groups the work and counts the children', (
        tester,
      ) async {
        final c = await _controller(tester);
        await _pump(
          tester,
          ParentHome(controller: c),
          size: size,
          controller: c,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Ҳолати имрӯзаи оилаи шумо'), findsOneWidget);
        expect(find.text('Корҳои имрӯз'), findsOneWidget);
        expect(find.text('Фарзандон'), findsOneWidget);
        // Counts carry their unit.
        expect(find.text('1 нафар'), findsOneWidget);
        expect(find.text('Барномаи баста'), findsOneWidget);
        expect(find.text('Ҳамаи барномаҳо'), findsOneWidget);
        // The bedtime row is labelled and shows its hours as the value.
        expect(find.text('Вақти хоб'), findsOneWidget);
        expect(find.text('21:30–07:00'), findsOneWidget);
      });

      testWidgets('apps screen explains itself and labels the limit', (
        tester,
      ) async {
        final c = await _controller(tester);
        await _pump(
          tester,
          Scaffold(body: AppsScreen(controller: c)),
          size: size,
          controller: c,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('apps-purpose')), findsOneWidget);
        expect(find.text('Реҷаҳо ва ҳисобот'), findsOneWidget);
        // Labelled tiles instead of a bare time range on a button.
        expect(find.text('Ҳисобот'), findsOneWidget);
        expect(find.text('7 рӯзи охир'), findsOneWidget);
        expect(find.text('Тамаркузи дарс'), findsOneWidget);
        // The limit slider has a name and a value with a unit.
        await _scrollTo(tester, find.text('Лимити рӯзона').first);
        expect(find.text('Лимити рӯзона'), findsWidgets);
        expect(find.text('Бе лимит'), findsWidgets);
        // Icon + label, not a bare icon.
        expect(find.text('Танзимоти дигар'), findsWidgets);
        expect(find.text('Кушода'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('an empty filter says what to do next', (tester) async {
        final c = await _controller(tester);
        await _pump(
          tester,
          Scaffold(body: AppsScreen(controller: c)),
          size: size,
          controller: c,
        );
        await tester.enterText(find.byType(TextField), 'zzzz');
        await tester.pumpAndSettle();
        expect(find.text('Чизе ёфт нашуд'), findsOneWidget);
        final action = find.text('Ҳамаи барномаҳоро нишон додан');
        expect(action, findsOneWidget);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        // Search and filter are cleared, the whole list is back.
        expect(find.text('Чизе ёфт нашуд'), findsNothing);
        expect(find.text('Барномаҳо (2)'), findsOneWidget);
        expect(find.text('Ҳама (2)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('requests inbox: purpose line and empty state action', (
        tester,
      ) async {
        final c = await _controller(tester);
        await _pump(
          tester,
          TimeRequestsScreen(controller: c),
          size: size,
          controller: c,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('requests-purpose')), findsOneWidget);
        expect(find.text('Дархости нав нест'), findsOneWidget);
        expect(find.text('Навсозӣ'), findsOneWidget);
      });

      testWidgets('weekly report opens with a purpose line', (tester) async {
        final c = await _controller(tester, withUsage: true);
        await _pump(
          tester,
          WeeklyReportScreen(api: c.api, child: c.selected!),
          size: size,
          controller: c,
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('report-purpose')), findsOneWidget);
        // Every bar carries its own «weekday: time» explanation.
        expect(find.byKey(const ValueKey('report-bar-0')), findsOneWidget);
      });

      testWidgets('bedtime and study sheets group their controls', (
        tester,
      ) async {
        final c = await _controller(tester);
        await _pump(
          tester,
          Scaffold(
            body: BedtimeSheet(controller: c, child: c.selected!),
          ),
          size: size,
          controller: c,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Соатҳои хоб'), findsOneWidget);
        expect(find.text('Аз соати'), findsOneWidget);
        expect(find.text('То соати'), findsOneWidget);

        await _pump(
          tester,
          Scaffold(
            body: StudySheet(controller: c, child: c.selected!),
          ),
          size: size,
          controller: c,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Соатҳои дарс'), findsOneWidget);
        expect(find.text('Рӯзҳои ҳафта'), findsOneWidget);
      });

      testWidgets('places: empty state leads to adding the first place', (
        tester,
      ) async {
        final c = await _controller(tester);
        var added = 0;
        await _pump(
          tester,
          Scaffold(
            body: PlacesSheet(
              controller: c,
              childId: c.selected!.id,
              onAdd: () => added++,
              onShow: (_) {},
            ),
          ),
          size: size,
          controller: c,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Ҳоло ҷойи бехатар нест'), findsOneWidget);
        await tester.tap(find.text('Ҷойи нав илова кардан'));
        await tester.pumpAndSettle();
        expect(added, 1);
      });

      testWidgets('a saved place is listed with its radius in metres', (
        tester,
      ) async {
        final c = await _controller(tester, withPlace: true);
        await _pump(
          tester,
          Scaffold(
            body: PlacesSheet(
              controller: c,
              childId: c.selected!.id,
              onAdd: () {},
              onShow: (_) {},
            ),
          ),
          size: size,
          controller: c,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Ҷойҳои шумо'), findsOneWidget);
        expect(find.text('1 ҷой'), findsOneWidget);
        expect(find.textContaining('Радиус 200 м'), findsOneWidget);
      });
    });
  }

  testWidgets('motion: lists fade in and collapse with «less motion»', (
    tester,
  ) async {
    final c = await _controller(tester);
    await _pump(tester, ParentHome(controller: c), controller: c);
    // Staggered FadeIn on the child list.
    expect(find.byType(FadeIn), findsWidgets);

    // With reduced motion the same screens build without any animation.
    await _pump(
      tester,
      ParentHome(controller: c),
      controller: c,
      noMotion: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FadeIn), findsWidgets);
    await _pump(
      tester,
      Scaffold(body: AppsScreen(controller: c)),
      controller: c,
      noMotion: true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab change fades through', (tester) async {
    final c = await _controller(tester);
    await _pump(tester, ParentHome(controller: c), controller: c);
    await tester.tap(find.text('Барномаҳо').last);
    await tester.pump(const Duration(milliseconds: 80));
    // Mid-transition both pages are on screen, fading.
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('apps-purpose')), findsOneWidget);
  });
}
