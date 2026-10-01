import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/parent_home.dart';
import 'package:nigoh_family_parent/features/settings/parent_pin.dart';

import 'parent_features_test.dart' show FakeServer, richSnapshot;

/// Native PIN store stand-in for `tj.nigoh/device_control`.
class _FakePin {
  _FakePin([this.pin]);
  String? pin;
  final calls = <String>[];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    final args = call.arguments is Map ? call.arguments as Map : const {};
    switch (call.method) {
      case 'getLocalPinStatus':
        return pin != null;
      case 'verifyLocalPin':
        return pin != null && args['pin'] == pin;
      case 'setLocalPin':
        if (pin != null && args['currentPin'] != pin) {
          return {'ok': false, 'error': 'wrong_current_pin'};
        }
        pin = args['newPin'] as String;
        return {'ok': true};
    }
    return null;
  }
}

Future<FakeServer> _pumpHome(WidgetTester tester, _FakePin pin) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(ParentPin.channel, pin.handle);
  addTearDown(
    () => messenger.setMockMethodCallHandler(ParentPin.channel, null),
  );
  final server = FakeServer(richSnapshot());
  final c = FamilyController(server.api, pollInterval: null);
  addTearDown(c.dispose);
  await tester.runAsync(c.refresh);
  await tester.pumpWidget(
    SessionScope(
      session: Session(api: server.api),
      child: MaterialApp(home: ParentHome(controller: c)),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

Future<void> _startRemove(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Бештар'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Хориҷ кардан'));
  await tester.pumpAndSettle();
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(TextField), pin);
  await tester.tap(find.text('Тасдиқ'));
  await tester.pumpAndSettle();
}

bool _deleted(FakeServer server) =>
    server.calls.any((c) => c.$1.startsWith('DELETE'));

void main() {
  testWidgets('no PIN yet: create it first, then verify, then delete', (
    tester,
  ) async {
    final pin = _FakePin();
    final server = await _pumpHome(tester, pin);
    await _startRemove(tester);

    // The set-PIN dialog comes first.
    expect(find.text('Гузоштани PIN'), findsOneWidget);
    expect(find.textContaining('Барои хориҷ кардани фарзанд'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '2468');
    await tester.enterText(find.byType(TextField).at(1), '2468');
    await tester.tap(find.text('Нигоҳ доштан'));
    await tester.pumpAndSettle();
    expect(pin.pin, '2468');

    // Then the PIN is asked for, then the confirmation.
    expect(find.text('PIN-ро ворид кунед'), findsOneWidget);
    await _enterPin(tester, '2468');
    expect(find.text('Сино-ро хориҷ кунем?'), findsOneWidget);
    expect(_deleted(server), isFalse);
    await tester.tap(find.text('Хориҷ кардан'));
    await tester.pumpAndSettle();
    expect(_deleted(server), isTrue);
  });

  testWidgets('no PIN and the parent cancels creating one: nothing deleted', (
    tester,
  ) async {
    final pin = _FakePin();
    final server = await _pumpHome(tester, pin);
    await _startRemove(tester);
    expect(find.text('Гузоштани PIN'), findsOneWidget);
    await tester.tap(find.text('Бекор'));
    await tester.pumpAndSettle();
    expect(find.text('PIN-ро ворид кунед'), findsNothing);
    expect(_deleted(server), isFalse);
  });

  testWidgets('wrong PIN shows an error and does not delete', (tester) async {
    final pin = _FakePin('1234');
    final server = await _pumpHome(tester, pin);
    await _startRemove(tester);
    expect(find.text('Гузоштани PIN'), findsNothing);
    await _enterPin(tester, '9999');
    expect(find.text('PIN нодуруст аст.'), findsOneWidget);
    expect(find.text('Сино-ро хориҷ кунем?'), findsNothing);
    await tester.tap(find.text('Бекор'));
    await tester.pumpAndSettle();
    expect(find.text('Сино-ро хориҷ кунем?'), findsNothing);
    expect(_deleted(server), isFalse);
  });

  testWidgets('right PIN then confirm sends DELETE', (tester) async {
    final pin = _FakePin('1234');
    final server = await _pumpHome(tester, pin);
    await _startRemove(tester);
    await _enterPin(tester, '1234');
    expect(find.text('Сино-ро хориҷ кунем?'), findsOneWidget);
    await tester.tap(find.text('Хориҷ кардан'));
    await tester.pumpAndSettle();
    expect(_deleted(server), isTrue);
    expect(
      pin.calls,
      containsAllInOrder(['getLocalPinStatus', 'verifyLocalPin']),
    );
  });

  testWidgets('PIN status error is shown and nothing is deleted', (
    tester,
  ) async {
    final server = await _pumpHome(tester, _FakePin());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ParentPin.channel,
      (_) async => throw PlatformException(code: 'x', message: 'Хато'),
    );
    await _startRemove(tester);
    expect(find.textContaining('PIN санҷида нашуд'), findsOneWidget);
    expect(find.text('Гузоштани PIN'), findsNothing);
    expect(_deleted(server), isFalse);
  });
}
