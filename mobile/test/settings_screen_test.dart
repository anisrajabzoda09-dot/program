import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/onboarding/child_setup_screen.dart';
import 'package:nigoh_family_parent/features/onboarding/role_screen.dart';
import 'package:nigoh_family_parent/features/settings/settings_screen.dart';
import 'package:nigoh_family_parent/features/settings/theme_mode.dart';
import 'package:nigoh_family_parent/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const device = MethodChannel('tj.nigoh/device_control');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Native calls the screen made, in order.
  late List<String> calls;

  /// What `getLocalPinStatus` answers and which PIN `verifyLocalPin` accepts.
  late bool pinSet;
  late String correctPin;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'NIGOH Family',
      packageName: 'tj.nigoh.family',
      version: '2.10.0',
      buildNumber: '38',
      buildSignature: '',
    );
    calls = [];
    pinSet = true;
    correctPin = '1234';
    messenger.setMockMethodCallHandler(device, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'getLocalPinStatus':
          return pinSet;
        case 'verifyLocalPin':
          return call.arguments['pin'] == correctPin;
        case 'requestUninstallWithPin':
          return {'ok': true};
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(device, null));

  Session session() => Session(
    api: NigohApi(client: MockClient((_) async => http.Response('{}', 200))),
  );

  Future<Session> pumpSettings(
    WidgetTester tester, {
    required String role,
  }) async {
    SharedPreferences.setMockInitialValues({
      'nigoh.token': 't',
      'nigoh.role': role,
      'nigoh.user': role == 'child' ? 'Сомон' : 'Модар',
    });
    final s = session();
    await s.load();
    await tester.pumpWidget(
      SessionScope(
        session: s,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return s;
  }

  final uninstallRow = find.byKey(const ValueKey('settings-uninstall'));

  testWidgets('settings shows profile, PIN status and changes theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'nigoh.token': 't',
      'nigoh.role': 'parent',
      'nigoh.user': 'Модар',
    });
    final s = session();
    await s.load();
    await tester.pumpWidget(
      SessionScope(
        session: s,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Модар'), findsOneWidget);
    expect(find.text('Волидайн'), findsOneWidget);
    expect(
      find.text('Фаъол аст — амалҳои муҳим PIN мепурсанд'),
      findsOneWidget,
    );
    // The settings list is longer now (language, wizard rows): scroll to the
    // version row, then back up to the appearance section.
    await tester.scrollUntilVisible(find.text('2.10.0 (38)'), 200);
    expect(find.text('2.10.0 (38)'), findsOneWidget);
    expect(find.text('Иҷозатҳо'), findsNothing);

    await tester.scrollUntilVisible(find.text('Торик'), -200);
    await tester.tap(find.text('Торик'));
    await tester.pumpAndSettle();
    expect(themeModeSetting.value, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeModeSetting.storageKey), 'dark');
    await themeModeSetting.set(ThemeMode.system);
  });

  testWidgets('child sees the «Нест кардани барнома» row, parent does not', (
    tester,
  ) async {
    await pumpSettings(tester, role: 'child');
    await tester.scrollUntilVisible(uninstallRow, 250);
    expect(uninstallRow, findsOneWidget);
    expect(find.text('Нест кардани барнома'), findsWidgets);
    expect(
      find.text(
        'PIN-и волидайнро мепурсад, баъд Android экрани несткуниро мекушояд.',
      ),
      findsOneWidget,
    );

    await pumpSettings(tester, role: 'parent');
    await tester.scrollUntilVisible(find.text('Баромадан аз аккаунт'), 250);
    expect(uninstallRow, findsNothing);
    expect(find.text('Нест кардани барнома'), findsNothing);
  });

  testWidgets('wrong PIN never reaches the native uninstall call', (
    tester,
  ) async {
    await pumpSettings(tester, role: 'child');
    await tester.scrollUntilVisible(uninstallRow, 250);
    await tester.tap(uninstallRow);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uninstall-pin')), findsOneWidget);
    // The dialog says plainly that the parent PIN is required.
    expect(
      find.textContaining('танҳо бо PIN-и волидайн мумкин аст'),
      findsOneWidget,
    );

    calls.clear();
    await tester.enterText(find.byKey(const Key('uninstall-pin')), '9999');
    await tester.tap(find.byKey(const Key('uninstall-confirm')));
    await tester.pumpAndSettle();

    expect(calls, ['verifyLocalPin']);
    expect(calls.contains('requestUninstallWithPin'), isFalse);
    expect(
      find.text('PIN нодуруст аст. Барнома нест карда нашуд.'),
      findsOneWidget,
    );
    // Still open: nothing happened.
    expect(find.byKey(const Key('uninstall-pin')), findsOneWidget);
  });

  testWidgets('correct PIN calls the native uninstall once', (tester) async {
    await pumpSettings(tester, role: 'child');
    await tester.scrollUntilVisible(uninstallRow, 250);
    await tester.tap(uninstallRow);
    await tester.pumpAndSettle();

    calls.clear();
    await tester.enterText(find.byKey(const Key('uninstall-pin')), '1234');
    await tester.tap(find.byKey(const Key('uninstall-confirm')));
    await tester.pumpAndSettle();

    expect(calls, ['verifyLocalPin', 'requestUninstallWithPin']);
    expect(
      calls.where((c) => c == 'requestUninstallWithPin').length,
      1,
      reason: 'Android uninstall screen is opened exactly once',
    );
    expect(find.byKey(const Key('uninstall-pin')), findsNothing);
    expect(
      find.text('Тасдиқ шуд. Android экрани несткуниро мекушояд.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'no parent PIN yet: the row explains it instead of uninstalling',
    (tester) async {
      pinSet = false;
      await pumpSettings(tester, role: 'child');
      await tester.scrollUntilVisible(uninstallRow, 250);
      expect(find.text('Аввал волидайн PIN гузорад.'), findsOneWidget);

      calls.clear();
      await tester.tap(uninstallRow);
      await tester.pumpAndSettle();
      expect(find.text('PIN-и волидайн гузошта нашудааст'), findsOneWidget);
      expect(calls, isEmpty);

      await tester.tap(find.text('Бекор'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    },
  );

  for (final size in const [Size(360, 780), Size(1280, 800)]) {
    testWidgets('child settings fit ${size.width.toInt()} px wide', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpSettings(tester, role: 'child');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(uninstallRow, 250);
      expect(tester.takeException(), isNull);
      expect(uninstallRow, findsOneWidget);
    });
  }

  testWidgets('gate shows role choice, then child setup', (tester) async {
    SharedPreferences.setMockInitialValues({'nigoh.token': 't'});
    final s = session();
    await s.load();
    await tester.pumpWidget(NigohApp(session: s));
    await tester.pumpAndSettle();
    expect(find.byType(RoleScreen), findsOneWidget);
    // Both choices say plainly what they mean.
    expect(find.text('Телефони ман'), findsOneWidget);
    expect(find.text('Телефони фарзанд'), findsOneWidget);

    await tester.tap(find.text('Фарзанд'));
    await tester.pumpAndSettle();
    expect(find.byType(ChildSetupScreen), findsOneWidget);
    expect(find.text('Маълумоти шумо'), findsOneWidget);
    expect(find.text('Нигоҳ доштан ва идома'), findsOneWidget);
  });

  for (final size in const [Size(360, 780), Size(1280, 800)]) {
    testWidgets('role and child setup fit ${size.width.toInt()} px wide', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({'nigoh.token': 't'});
      final s = session();
      await s.load();
      await tester.pumpWidget(NigohApp(session: s));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Фарзанд'));
      await tester.pumpAndSettle();
      expect(find.byType(ChildSetupScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
