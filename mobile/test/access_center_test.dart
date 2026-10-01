import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/pages/access_center_page.dart';

void main() {
  const channel = MethodChannel('tj.nigoh/device_control');
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('admin alone is not reported as app-blocking readiness', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {'deviceAdmin': true, 'usage': false, 'overlay': false},
        );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AccessCenterPage(childMode: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Бастани барномаҳо ҳоло омода нест'), findsOneWidget);
    expect(
      find.text('«Restricted setting» ё «App was denied access»?'),
      findsOneWidget,
    );
  });

  testWidgets('settings opens with bool result and refreshes on return', (
    tester,
  ) async {
    bool ready = false;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'openAppDetails') return true;
          return {
            'usage': ready,
            'overlay': ready,
            'accessibility': ready,
            'deviceAdmin': false,
          };
        });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AccessCenterPage(childMode: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Кушодани App info'));
    await tester.tap(find.text('Кушодани App info'));
    await tester.pumpAndSettle();
    expect(calls, contains('openAppDetails'));
    expect(tester.takeException(), isNull);
    ready = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(
      find.text('Иҷозатҳои бастани барномаҳо дода шуданд'),
      findsOneWidget,
    );
  });

  testWidgets('native failure is recoverable and does not claim readiness', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AccessCenterPage(childMode: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Ҳолати иҷозатҳо санҷида нашуд. Дубора кӯшиш кунед.'),
      findsOneWidget,
    );
    expect(find.text('Иҷозатҳои бастани барномаҳо дода шуданд'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
