import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/auth/auth_screen.dart';
import 'package:nigoh_family_parent/features/onboarding/role_screen.dart';
import 'package:nigoh_family_parent/features/settings/settings_screen.dart';
import 'package:nigoh_family_parent/l10n/l10n.dart';
import 'package:nigoh_family_parent/l10n/strings_core.dart';
import 'package:nigoh_family_parent/ui/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Russian and English on the shared screens (auth, role, settings).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const device = MethodChannel('tj.nigoh/device_control');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'NIGOH Family',
      packageName: 'tj.nigoh.family',
      version: '2.17.0',
      buildNumber: '60',
      buildSignature: '',
    );
    messenger.setMockMethodCallHandler(device, (call) async {
      if (call.method == 'getLocalPinStatus') return true;
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(device, null);
    appLanguage.value = 'tg';
  });

  Future<Session> signedIn(String role) async {
    SharedPreferences.setMockInitialValues({
      'nigoh.token': 't',
      'nigoh.role': role,
      'nigoh.user': 'Модар',
    });
    final session = Session(
      api: NigohApi(client: MockClient((_) async => http.Response('{}', 200))),
    );
    await session.load();
    return session;
  }

  Future<void> pump(WidgetTester tester, Session session, Widget screen) async {
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: MaterialApp(theme: NigohTheme.light(), home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('coreStrings entries all have ru + en with the same placeholders', () {
    final ph = RegExp(r'\{(\w+)\}');
    Set<String> names(String s) => ph.allMatches(s).map((m) => m[1]!).toSet();
    expect(coreStrings.length, greaterThan(100));
    coreStrings.forEach((tg, pair) {
      expect(pair.length, 2, reason: tg);
      expect(pair[0].trim(), isNotEmpty, reason: 'ru missing: $tg');
      expect(pair[1].trim(), isNotEmpty, reason: 'en missing: $tg');
      expect(names(pair[0]), names(tg), reason: 'ru placeholders: $tg');
      expect(names(pair[1]), names(tg), reason: 'en placeholders: $tg');
    });
  });

  testWidgets('auth screen in Russian and English', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = Session(
      api: NigohApi(client: MockClient((_) async => http.Response('{}', 200))),
    );
    await session.load();

    appLanguage.value = 'ru';
    await pump(tester, session, const AuthScreen());
    expect(find.text('Войти'), findsWidgets);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Войдите по своей почте и паролю.'), findsOneWidget);

    appLanguage.value = 'en';
    await pump(tester, session, const AuthScreen());
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Sign in with your email and password.'), findsOneWidget);
  });

  testWidgets('role screen in Russian', (tester) async {
    SharedPreferences.setMockInitialValues({'nigoh.token': 't'});
    final session = Session(
      api: NigohApi(client: MockClient((_) async => http.Response('{}', 200))),
    );
    await session.load();
    appLanguage.value = 'ru';
    await pump(tester, session, const RoleScreen());
    expect(find.textContaining('Выбор делается один раз'), findsOneWidget);
    expect(find.text('Мой телефон'), findsOneWidget);
    expect(find.text('Телефон ребёнка'), findsOneWidget);
  });

  testWidgets('child settings, including the uninstall row, in English', (
    tester,
  ) async {
    final session = await signedIn('child');
    appLanguage.value = 'en';
    await pump(tester, session, const SettingsScreen());
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Parent PIN and Android permissions.'), findsOneWidget);

    final row = find.byKey(const ValueKey('settings-uninstall'));
    await tester.scrollUntilVisible(row, 250);
    expect(find.text('Uninstall the app'), findsWidgets);
    expect(
      find.text(
        'NIGOH is not hidden. The app can be removed, but the parent PIN is required.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('child settings uninstall row in Russian', (tester) async {
    final session = await signedIn('child');
    appLanguage.value = 'ru';
    await pump(tester, session, const SettingsScreen());
    final row = find.byKey(const ValueKey('settings-uninstall'));
    await tester.scrollUntilVisible(row, 250);
    expect(find.text('Удалить приложение'), findsWidgets);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.textContaining('только с PIN родителя'), findsOneWidget);
  });
}
