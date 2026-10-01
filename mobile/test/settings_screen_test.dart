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

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'NIGOH Family',
      packageName: 'tj.nigoh.family',
      version: '2.10.0',
      buildNumber: '38',
      buildSignature: '',
    );
    messenger.setMockMethodCallHandler(device, (call) async {
      if (call.method == 'getLocalPinStatus') return true;
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(device, null));

  Session session() => Session(
    api: NigohApi(client: MockClient((_) async => http.Response('{}', 200))),
  );

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
    expect(find.text('Фаъол аст'), findsOneWidget);
    expect(find.text('2.10.0 (38)'), findsOneWidget);
    expect(find.text('Иҷозатҳо'), findsNothing);

    await tester.tap(find.text('Торик'));
    await tester.pumpAndSettle();
    expect(themeModeSetting.value, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeModeSetting.storageKey), 'dark');
    await themeModeSetting.set(ThemeMode.system);
  });

  testWidgets('gate shows role choice, then child setup', (tester) async {
    SharedPreferences.setMockInitialValues({'nigoh.token': 't'});
    final s = session();
    await s.load();
    await tester.pumpWidget(NigohApp(session: s));
    await tester.pumpAndSettle();
    expect(find.byType(RoleScreen), findsOneWidget);

    await tester.tap(find.text('Фарзанд'));
    await tester.pumpAndSettle();
    expect(find.byType(ChildSetupScreen), findsOneWidget);
  });
}
