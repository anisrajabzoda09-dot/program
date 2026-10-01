import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/home_target.dart';
import 'package:nigoh_family_parent/core/notify_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  Object? pendingLaunch;
  Map<String, Object?> permissions = {};

  setUp(() {
    NotifyBridge.resetForTest();
    calls = [];
    pendingLaunch = null;
    permissions = {'notifications': true, 'fullScreen': true};
    messenger.setMockMethodCallHandler(NotifyBridge.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getLaunchAction':
          final value = pendingLaunch;
          pendingLaunch = null;
          return value;
        case 'permissionStatus':
          return permissions;
        default:
          return true;
      }
    });
  });

  tearDown(
    () => messenger.setMockMethodCallHandler(NotifyBridge.channel, null),
  );

  NigohApi api() => NigohApi(
    client: MockClient((_) async => http.Response('{}', 200)),
    baseUrl: 'https://example.test',
  );

  test('start passes baseUrl and picks up the cold-start launch', () async {
    pendingLaunch = {
      'kind': 'call',
      'childId': 7,
      'callId': 42,
      'peerName': 'Модар',
      'acceptCall': true,
      'fullScreen': false,
    };
    await NotifyBridge.start(api());
    final start = calls.singleWhere((c) => c.method == 'start');
    expect((start.arguments as Map)['baseUrl'], 'https://example.test');
    final action = NotifyBridge.launch.value!;
    expect(action.kind, 'call');
    expect(action.childId, 7);
    expect(action.callId, 42);
    expect(action.peerName, 'Модар');
    expect(action.acceptCall, isTrue);
    expect(NotifyBridge.lastError.value, isNull);
  });

  test('stop invokes the native stop', () async {
    await NotifyBridge.stop();
    expect(calls.map((c) => c.method), ['stop']);
  });

  test('launch from native while running updates the notifier', () async {
    await NotifyBridge.init();
    await messenger.handlePlatformMessage(
      NotifyBridge.channel.name,
      NotifyBridge.channel.codec.encodeMethodCall(
        const MethodCall('launch', {'kind': 'message', 'childId': 3}),
      ),
      (_) {},
    );
    final action = NotifyBridge.launch.value!;
    expect(action.kind, 'message');
    expect(action.childId, 3);
    expect(action.callId, isNull);
    expect(action.acceptCall, isFalse);
  });

  test('LaunchAction.fromMap tolerates bad input', () {
    expect(LaunchAction.fromMap(null), isNull);
    expect(LaunchAction.fromMap({'childId': 1}), isNull);
    final a = LaunchAction.fromMap({
      'kind': 'sos',
      'childId': '5',
      'callId': null,
      'peerName': '',
      'fullScreen': true,
    })!;
    expect(a.childId, 5);
    expect(a.peerName, isNull);
    expect(a.fullScreen, isTrue);
  });

  test('platform errors are kept visible in lastError', () async {
    messenger.setMockMethodCallHandler(NotifyBridge.channel, (call) async {
      if (call.method == 'start') {
        throw PlatformException(code: 'x', message: 'Хато');
      }
      return null;
    });
    await NotifyBridge.start(api());
    expect(NotifyBridge.lastError.value, 'Хато');
  });

  test('HomeTarget maps event kinds', () {
    expect(
      HomeTarget.forEvent('message', 1),
      const HomeTarget('chat', childId: 1),
    );
    expect(HomeTarget.forEvent('sos', 2).kind, 'map');
    expect(HomeTarget.forEvent('time_request', 2).kind, 'requests');
    expect(HomeTarget.forEvent('new_app', 2).kind, 'overview');
  });

  testWidgets('ensurePermissions explains and opens full-screen settings', (
    tester,
  ) async {
    permissions = {'notifications': true, 'fullScreen': false};
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final result = NotifyBridge.ensurePermissions(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Огоҳиномаҳо дар экрани пурра'), findsOneWidget);
    await tester.tap(find.text('Кушодани танзимот'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(calls.map((c) => c.method), contains('openFullScreenSettings'));
  });
}
