import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/features/child/child_home.dart';
import 'package:nigoh_family_parent/features/child/child_sync.dart';
import 'package:qr_flutter/qr_flutter.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  const channel = MethodChannel('tj.nigoh/device_control');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getProtectionStatus') {
            return {
              'usage': true,
              'overlay': true,
              'accessibility': true,
              'location': true,
              'notifications': true,
            };
          }
          if (call.method == 'getInstalledApps') {
            return [
              {'packageName': 'com.a', 'appName': 'A'},
            ];
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<ChildSync> pump(
    WidgetTester tester,
    Map<String, dynamic> child,
  ) async {
    final sync = ChildSync(
      api: NigohApi(
        client: MockClient((req) async {
          if (req.url.path == '/api/mobile/v2/snapshot') {
            return json({'child': child});
          }
          return json({'status': 'success'});
        }),
        baseUrl: 'http://t',
      ),
      trackLocation: false,
      listenPackageEvents: false,
    );
    await tester.pumpWidget(MaterialApp(home: ChildHome(sync: sync)));
    await tester.pumpAndSettle();
    return sync;
  }

  Future<void> finish(WidgetTester tester, ChildSync sync) async {
    await tester.pumpWidget(const SizedBox());
    sync.dispose();
  }

  testWidgets('not paired: QR and spaced code', (tester) async {
    final sync = await pump(tester, {
      'id': 5,
      'pairing_code': '482913',
      'is_paired': false,
      'apps': [],
    });
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('Коди нав'), findsOneWidget);
    await finish(tester, sync);
  });

  testWidgets('paired: status cards with parent name', (tester) async {
    final sync = await pump(tester, {
      'id': 5,
      'pairing_code': '482913',
      'is_paired': true,
      'parent_name': 'Модар',
      'apps': [],
    });
    expect(find.text('Пайваст бо Модар'), findsOneWidget);
    expect(find.text('Ҳамаи иҷозатҳо дода шудаанд'), findsOneWidget);
    expect(find.text('1 барнома'), findsOneWidget);
    expect(find.text('Барномаҳо'), findsOneWidget);
    await finish(tester, sync);
  });
}
