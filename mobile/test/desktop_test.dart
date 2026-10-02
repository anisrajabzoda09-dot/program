import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/home_target.dart';
import 'package:nigoh_family_parent/core/platform.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/auth/auth_screen.dart';
import 'package:nigoh_family_parent/features/desktop/desktop_notifications.dart';
import 'package:nigoh_family_parent/features/onboarding/permissions_wizard.dart';
import 'package:nigoh_family_parent/features/onboarding/role_screen.dart';
import 'package:nigoh_family_parent/features/parent/add_child_screen.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';
import 'package:nigoh_family_parent/features/settings/app_update.dart';
import 'package:nigoh_family_parent/features/settings/parent_pin.dart';
import 'package:nigoh_family_parent/features/settings/profile_photo.dart';
import 'package:nigoh_family_parent/l10n/l10n.dart';
import 'package:nigoh_family_parent/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'family_controller_test.dart' show snapshotJson;

final windows = TargetPlatformVariant.only(TargetPlatform.windows);

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

NigohApi _api([Map<String, dynamic> Function(http.Request r)? route]) =>
    NigohApi(
      client: MockClient((r) async => _json(route?.call(r) ?? const {})),
    );

Widget _app(Session session, Widget home) => SessionScope(
  session: session,
  child: MaterialApp(home: home),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appLanguage.value = 'tg';
  });

  tearDown(() => AppPlatform.debugPlatformOverride = null);

  test('platform helper follows the target platform under test', () {
    expect(isAndroidApp, isTrue);
    expect(isDesktop, isFalse);
    AppPlatform.debugPlatformOverride = TargetPlatform.windows;
    expect(isDesktop, isTrue);
    expect(isAndroidApp, isFalse);
  });

  testWidgets('role screen offers only the parent on desktop', (tester) async {
    final session = Session(api: _api());
    await tester.pumpWidget(_app(session, const RoleScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Волидайн'), findsOneWidget);
    expect(find.text('Фарзанд'), findsNothing);
    expect(find.byKey(const Key('role.child-on-phone')), findsOneWidget);
    expect(
      find.text('NIGOH Family дар компютер барои волидайн аст.'),
      findsOneWidget,
    );

    appLanguage.value = 'en';
    await tester.pumpWidget(_app(session, const RoleScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('NIGOH Family on a computer is for parents.'),
      findsOneWidget,
    );
    appLanguage.value = 'tg';
  }, variant: windows);

  testWidgets('role screen still offers both roles on Android', (tester) async {
    await tester.pumpWidget(_app(Session(api: _api()), const RoleScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Волидайн'), findsOneWidget);
    expect(find.text('Фарзанд'), findsOneWidget);
  });

  testWidgets('a stored child role on desktop shows the role screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'nigoh.token': 't',
      'nigoh.role': 'child',
    });
    final session = Session(api: _api());
    await session.load();
    await tester.pumpWidget(NigohApp(session: session));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RoleScreen), findsOneWidget);
    expect(DesktopNotifications.active.value, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, variant: windows);

  testWidgets('Google sign-in is hidden on desktop', (tester) async {
    await tester.pumpWidget(_app(Session(api: _api()), const AuthScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('auth.google')), findsNothing);
    expect(find.byKey(const Key('auth.email')), findsOneWidget);
    expect(find.byKey(const Key('auth.submit')), findsOneWidget);
  }, variant: windows);

  testWidgets('Google sign-in stays on Android', (tester) async {
    await tester.pumpWidget(_app(Session(api: _api()), const AuthScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('auth.google')), findsOneWidget);
  });

  testWidgets('add child on desktop has no QR scanner, only the code', (
    tester,
  ) async {
    final c = FamilyController(_api(), pollInterval: null);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      _app(Session(api: c.api), AddChildScreen(controller: c)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Скан кардани QR'), findsNothing);
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    expect(
      find.text('Рамзи 6-рақамаро аз телефони фарзанд ворид кунед'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add-child.code')), findsOneWidget);
  }, variant: windows);

  testWidgets('add child on Android keeps the scanner button', (tester) async {
    final c = FamilyController(_api(), pollInterval: null);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      _app(Session(api: c.api), AddChildScreen(controller: c)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Скан кардани QR'), findsOneWidget);
  });

  testWidgets(
    'desktop parent skips the permissions wizard and runs the event loop',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'nigoh.token': 't',
        'nigoh.role': 'parent',
        'nigoh.user': 'Модар',
      });
      final session = Session(
        api: _api((r) {
          return r.url.path.endsWith('/events')
              ? {'events': [], 'latest_id': 5}
              : {'children': []};
        }),
      );
      await session.load();
      await tester.pumpWidget(NigohApp(session: session));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PermissionsWizard), findsNothing);
      expect(find.byType(ParentHome), findsOneWidget);
      expect(DesktopNotifications.active.value, isTrue);

      await session.signOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(DesktopNotifications.active.value, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
    variant: windows,
  );

  testWidgets('settings on desktop hide the wizard row', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'nigoh.role': 'parent'});
    final session = Session(api: _api());
    await session.load();
    await tester.pumpWidget(_app(session, const ParentHome()));
    await tester.pump();
    // Go to the Settings tab.
    await tester.tap(find.text('Танзимот').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('settings-wizard')), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-desktop-notify')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, variant: windows);

  group('parent home layout', () {
    Future<FamilyController> loaded(WidgetTester tester) async {
      final c = FamilyController(
        _api((_) => snapshotJson()),
        pollInterval: null,
      );
      await tester.runAsync(c.refresh);
      return c;
    }

    testWidgets('NavigationRail at 1280x800', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await loaded(tester);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _app(Session(api: c.api), ParentHome(controller: c)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // Content is limited to a centered column.
      final column = find.byWidgetPredicate(
        (w) =>
            w is ConstrainedBox &&
            w.constraints.maxWidth == ParentHome.maxContentWidth,
      );
      expect(column, findsOneWidget);
      expect(
        find.descendant(of: column, matching: find.text('Сино')),
        findsWidgets,
      );
      final rect = tester.getRect(column);
      expect(rect.width, ParentHome.maxContentWidth);
      final pane = tester.getRect(find.byType(Scaffold).first);
      expect(
        (rect.left - pane.left - (pane.right - rect.right)).abs(),
        lessThan(1),
      );
      // Rail switches tabs.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Харита'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        2,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }, variant: windows);

    testWidgets('NavigationBar at 390x800', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await loaded(tester);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _app(Session(api: c.api), ParentHome(controller: c)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }, variant: windows);
  });

  group('desktop event loop', () {
    late List<String> sounds;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      sounds = [];
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemSound.play') sounds.add('${call.arguments}');
        return null;
      });
      homeTarget.value = null;
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      homeTarget.value = null;
    });

    testWidgets('shows a message banner and a ringing SOS dialog', (
      tester,
    ) async {
      final afterIds = <String>[];
      final queue = <Map<String, Object>>[
        {'events': [], 'latest_id': 10},
        {
          'events': [
            {
              'id': 11,
              'child_id': 7,
              'child_name': 'Сино',
              'kind': 'message',
              'title': 'Сино',
              'body': 'Салом, модар!',
              'data': {'sender': 'Сино'},
            },
          ],
          'latest_id': 11,
        },
        {
          'events': [
            {
              'id': 12,
              'child_id': 7,
              'child_name': 'Сино',
              'kind': 'sos',
              'title': 'SOS — Сино',
              'body': '',
              'data': {},
            },
          ],
          'latest_id': 12,
        },
      ];
      final api = NigohApi(
        client: MockClient((r) async {
          afterIds.add(r.url.queryParameters['after_id']!);
          return _json(
            queue.isEmpty ? {'events': [], 'latest_id': 12} : queue.removeAt(0),
          );
        }),
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      final alerts = DesktopAlerts(
        navigatorKey,
        soundInterval: const Duration(seconds: 2),
      );
      final loop = DesktopEventLoop(
        api,
        onEvent: alerts.handle,
        gap: const Duration(milliseconds: 100),
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('home')),
        ),
      );
      loop.start();
      // Position fix (no backlog), then the message.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Салом, модар!'), findsOneWidget);
      expect(find.text('Сино'), findsOneWidget);
      expect(afterIds.take(2), ['0', '10']);

      // Then the SOS: red dialog, alarm repeats until silenced.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('desktop-sos')), findsOneWidget);
      expect(find.text('SOS — Сино'), findsOneWidget);
      expect(
        find.text('Сино ёрӣ мехоҳад. Ҷойгиршавиро бинед.'),
        findsOneWidget,
      );
      expect(alerts.sosRinging, isTrue);
      final before = sounds.length;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(sounds.length, greaterThanOrEqualTo(before + 2));
      expect(sounds.last, contains('alert'));

      loop.stop();
      await tester.tap(find.text('Хомӯш кардан'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('desktop-sos')), findsNothing);
      expect(alerts.sosRinging, isFalse);
      // Routed like a tap on the Android notification.
      expect(homeTarget.value, const HomeTarget('map', childId: 7));
      final after = sounds.length;
      await tester.pump(const Duration(seconds: 5));
      expect(sounds.length, after);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }, variant: windows);

    testWidgets('banner texts follow the app language', (tester) async {
      appLanguage.value = 'ru';
      addTearDown(() => appLanguage.value = 'tg');
      const event = DesktopEvent(
        id: 3,
        kind: 'low_battery',
        childId: 7,
        childName: 'Сино',
        title: 'Батарея',
        data: {'battery': 9},
      );
      expect(event.localizedTitle, 'Сино: батарея 9%');
      expect(event.localizedBody, 'Телефон ребёнка скоро выключится.');
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      DesktopAlerts(navigatorKey).handle(event);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Телефон ребёнка скоро выключится.'), findsOneWidget);
      await tester.tap(find.text('Открыть'));
      await tester.pump();
      expect(homeTarget.value, const HomeTarget('map', childId: 7));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }, variant: windows);

    test('errors are kept for a visible status and the loop retries', () async {
      var calls = 0;
      final api = NigohApi(
        client: MockClient((_) async {
          calls++;
          return http.Response('{"detail":"x"}', 500);
        }),
      );
      final loop = DesktopEventLoop(
        api,
        onEvent: (_) {},
        retryDelay: const Duration(milliseconds: 20),
      );
      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      loop.stop();
      expect(loop.lastError.value, isNotNull);
      expect(calls, greaterThan(1));
    });
  });

  group('desktop helpers', () {
    testWidgets('update check shows the latest version and the download link', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'NIGOH Family',
        packageName: 'nigoh',
        version: '2.16.0',
        buildNumber: '44',
        buildSignature: '',
      );
      Uri? opened;
      final original = AppUpdate.openUrl;
      AppUpdate.openUrl = (url) async {
        opened = url;
        return true;
      };
      addTearDown(() => AppUpdate.openUrl = original);
      final api = _api(
        (_) => {
          'update_available': true,
          'version': '2.17.0',
          'version_code': 45,
          'download_url': 'https://example.test/app.apk',
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppUpdate.check(context, api),
              child: const Text('check'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('desktop-update')), findsOneWidget);
      expect(find.text('Версияи охирин: 2.17.0'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('desktop-update-open')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, AppUpdate.downloadPage);
      expect(opened.toString(), 'https://nigohfamily.qobus.tj/get');
    }, variant: windows);

    testWidgets('profile photo on desktop has no camera option', (
      tester,
    ) async {
      final session = Session(api: _api());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfileAvatarButton(session: session)),
        ),
      );
      await tester.tap(find.byType(ProfileAvatarButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('avatar-gallery')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar-camera')), findsNothing);
    }, variant: windows);

    testWidgets('parent PIN is stored locally on desktop', (tester) async {
      expect(await ParentPin.isSet(), isFalse);
      expect(await ParentPin.change(currentPin: '', newPin: '1234'), isNull);
      expect(await ParentPin.isSet(), isTrue);
      expect(await ParentPin.verify('1234'), isTrue);
      expect(await ParentPin.verify('0000'), isFalse);
      expect(
        await ParentPin.change(currentPin: '9999', newPin: '5555'),
        'Рамзи ҷорӣ нодуруст аст.',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(DesktopPinStore.key), isNot(contains('1234')));
    }, variant: windows);
  });
}
