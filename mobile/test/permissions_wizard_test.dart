import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/onboarding/permissions_wizard.dart';
import 'package:nigoh_family_parent/main.dart';
import 'package:nigoh_family_parent/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// permission_handler codes.
const denied = 0, granted = 1, permanentlyDenied = 4;
const pLocationAlways = 4, pWhenInUse = 5, pMicrophone = 7;
const pBattery = 16, pNotification = 17, pCamera = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const ph = MethodChannel('flutter.baseflow.com/permissions/methods');
  const device = MethodChannel('tj.nigoh/device_control');
  const notify = MethodChannel('tj.nigoh/notify');

  late Map<int, int> perms;
  late Map<String, Object?> protection;
  late bool fullScreen;
  late List<String> calls;

  /// What a request / settings screen grants (simulates the user).
  late Map<String, void Function()> onCall;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PermissionsWizard.shownThisSession = false;
    perms = {};
    protection = {
      'usage': false,
      'overlay': false,
      'accessibility': false,
      'deviceAdmin': false,
    };
    fullScreen = false;
    calls = [];
    onCall = {};
    messenger.setMockMethodCallHandler(ph, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return perms[call.arguments as int] ?? denied;
        case 'checkServiceStatus':
          return 1;
        case 'requestPermissions':
          final list = (call.arguments as List).cast<int>();
          calls.add('request:${list.join(',')}');
          onCall['request:${list.join(',')}']?.call();
          return {for (final p in list) p: perms[p] ?? denied};
        case 'openAppSettings':
          calls.add('openAppSettings');
          onCall['openAppSettings']?.call();
          return true;
        case 'shouldShowRequestPermissionRationale':
          return false;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(device, (call) async {
      if (call.method == 'getProtectionStatus') return protection;
      calls.add(call.method);
      onCall[call.method]?.call();
      return true;
    });
    messenger.setMockMethodCallHandler(notify, (call) async {
      if (call.method == 'permissionStatus') {
        return {
          'notifications': perms[pNotification] == granted,
          'fullScreen': fullScreen,
        };
      }
      calls.add('notify:${call.method}');
      onCall['notify:${call.method}']?.call();
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(ph, null);
    messenger.setMockMethodCallHandler(device, null);
    messenger.setMockMethodCallHandler(notify, null);
  });

  var doneCount = 0;
  Future<void> pumpWizard(WidgetTester tester, {required bool child}) async {
    doneCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: NigohTheme.light(),
        home: PermissionsWizard(
          key: ValueKey(child),
          childMode: child,
          onDone: () => doneCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> later(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byKey(const Key('wizard-later')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapIt(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> grant(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('wizard-grant')));
    await tester.pumpAndSettle();
  }

  test('steps for child and parent', () {
    expect(wizardStepsFor(childMode: true), [
      WizardStepId.location,
      WizardStepId.notifications,
      WizardStepId.usage,
      WizardStepId.overlay,
      WizardStepId.accessibility,
      WizardStepId.deviceAdmin,
      WizardStepId.microphone,
      WizardStepId.battery,
    ]);
    expect(wizardStepsFor(childMode: false), [
      WizardStepId.notifications,
      WizardStepId.fullScreen,
      WizardStepId.camera,
      WizardStepId.microphone,
      WizardStepId.battery,
    ]);
  });

  testWidgets('child wizard starts at location, parent at notifications', (
    tester,
  ) async {
    await pumpWizard(tester, child: true);
    expect(find.text('Қадами 1 аз 8'), findsOneWidget);
    expect(find.text('Ҷойгиршавӣ'), findsOneWidget);
    expect(find.text('Иҷозат додан'), findsOneWidget);

    await pumpWizard(tester, child: false);
    expect(find.text('Қадами 1 аз 5'), findsOneWidget);
    expect(find.text('Огоҳиномаҳо'), findsOneWidget);
    await later(tester);
    expect(find.text('Экрани пурра'), findsOneWidget);
    await grant(tester);
    expect(calls, ['notify:openFullScreenSettings']);
  });

  testWidgets('location asks while-in-use, then always', (tester) async {
    onCall['request:$pWhenInUse'] = () => perms[pWhenInUse] = granted;
    await pumpWizard(tester, child: true);
    await grant(tester);
    expect(calls, ['request:$pWhenInUse']);
    expect(find.text('Ҷойгиршавӣ — «Ҳамеша»'), findsOneWidget);
    expect(find.byKey(const Key('wizard-fallback')), findsNothing);
    await grant(tester);
    expect(calls.last, 'request:$pLocationAlways');
    // Still not granted after returning: the fallback appears.
    final fallback = find.byKey(const Key('wizard-fallback'));
    expect(fallback, findsOneWidget);
    await tapIt(tester, fallback);
    expect(calls.last, 'openAppSettings');
  });

  testWidgets('special permissions call the right native openers', (
    tester,
  ) async {
    await pumpWizard(tester, child: true);
    await later(tester, 2);
    expect(find.text('Дастрасӣ ба истифода'), findsOneWidget);
    expect(find.byKey(const Key('wizard-fallback')), findsNothing);
    await grant(tester);
    expect(calls, ['openUsageSettings']);

    final fallback = find.byKey(const Key('wizard-fallback'));
    expect(fallback, findsOneWidget);
    await tapIt(tester, fallback);
    expect(calls, ['openUsageSettings', 'openUsageSettings']);

    await later(tester);
    expect(find.text('Намоиш болои барномаҳо'), findsOneWidget);
    expect(find.byKey(const Key('wizard-fallback')), findsNothing);
    await grant(tester);
    expect(calls.last, 'openOverlaySettings');

    await later(tester);
    expect(find.text('Специальные возможности'), findsOneWidget);
    await grant(tester);
    expect(calls.last, 'openAccessibilitySettingsDirect');
    // Fallback goes to App details (restricted settings menu).
    await tapIt(tester, fallback);
    expect(calls.last, 'openAppSettings');

    await later(tester);
    expect(find.text('Ҳимоя аз нест кардан'), findsOneWidget);
    await grant(tester);
    expect(calls.last, 'openDeviceAdminSettings');

    await later(tester);
    expect(find.text('Микрофон'), findsOneWidget);
    await grant(tester);
    expect(calls.last, 'request:$pMicrophone');

    await later(tester);
    expect(find.text('Батарея'), findsOneWidget);
    await grant(tester);
    expect(calls.last, 'request:$pBattery');
  });

  testWidgets('permanently denied shows fallback at once and opens settings', (
    tester,
  ) async {
    perms[pCamera] = permanentlyDenied;
    await pumpWizard(tester, child: false);
    await later(tester, 2);
    expect(find.text('Камера'), findsOneWidget);
    expect(find.byKey(const Key('wizard-fallback')), findsOneWidget);
    await grant(tester);
    expect(calls, ['openAppSettings']);
  });

  testWidgets('help card expands with numbered steps', (tester) async {
    await pumpWizard(tester, child: true);
    await later(tester, 4);
    expect(find.text('Специальные возможности'), findsOneWidget);
    expect(find.textContaining('Разрешить ограниченные настройки'), findsNothing);
    final help = find.byKey(const Key('wizard-help'));
    await tapIt(tester, help);
    expect(
      find.textContaining('Разрешить ограниченные настройки'),
      findsOneWidget,
    );
    expect(find.textContaining('Доступ запрещен'), findsWidgets);
    expect(find.textContaining('Автоблокировка'), findsOneWidget);
    // Prerequisite hint (usage/overlay still missing).
    expect(find.textContaining('тугма аввал'), findsOneWidget);
    await tapIt(tester, help);
    expect(find.textContaining('Автоблокировка'), findsNothing);
  });

  testWidgets('auto-advances after the permission is granted', (tester) async {
    onCall['openUsageSettings'] = () => protection['usage'] = true;
    await pumpWizard(tester, child: true);
    await later(tester, 2);
    await tester.tap(find.byKey(const Key('wizard-grant')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Иҷозат дода шуд'), findsOneWidget);
    expect(find.text('Қадами 3 аз 8'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Қадами 4 аз 8'), findsOneWidget);

    // Granted in Settings, detected on resume.
    protection['overlay'] = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Қадами 5 аз 8'), findsOneWidget);
  });

  testWidgets('summary lists status and jumps back to a missing step', (
    tester,
  ) async {
    perms[pNotification] = granted;
    fullScreen = true;
    perms[pCamera] = granted;
    perms[pMicrophone] = granted;
    await pumpWizard(tester, child: false);
    expect(find.text('Батарея'), findsOneWidget);
    await later(tester);
    expect(find.text('Ҳамааш тайёр'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
    await tapIt(tester, find.byKey(const Key('wizard-summary-battery')));
    expect(find.text('Қадами 5 аз 5'), findsOneWidget);
  });

  testWidgets('finish stores the done flag per role', (tester) async {
    await pumpWizard(tester, child: true);
    await tester.tap(find.byKey(const Key('wizard-close')));
    await tester.pumpAndSettle();
    expect(doneCount, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('nigoh.wizard_done.child'), isTrue);
    expect(prefs.getBool('nigoh.wizard_done.parent'), isNull);
    expect(await PermissionsWizard.isDone('child'), isTrue);
  });

  testWidgets('root gate shows the wizard once for a parent', (tester) async {
    SharedPreferences.setMockInitialValues({
      'nigoh.token': 't',
      'nigoh.role': 'parent',
      'nigoh.user': 'Модар',
    });
    final session = Session(
      api: NigohApi(client: MockClient((_) async => http.Response('{}', 200))),
    );
    await session.load();
    await tester.pumpWidget(NigohApp(session: session));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionsWizard), findsOneWidget);
    expect(find.text('Қадами 1 аз 5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wizard-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PermissionsWizard), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('nigoh.wizard_done.parent'), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    // Next start: straight to the home.
    final again = Session(
      api: NigohApi(client: MockClient((_) async => http.Response('{}', 200))),
    );
    await again.load();
    await tester.pumpWidget(NigohApp(session: again));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PermissionsWizard), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
