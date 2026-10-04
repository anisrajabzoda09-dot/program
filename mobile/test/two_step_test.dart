// Файл: санҷишҳои ҳимояи дуқабата дар барнома — session, равзанаи рамз, рамз ба почта ва экрани танзим.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/auth/auth_screen.dart';
import 'package:nigoh_family_parent/features/settings/two_step_screen.dart';
import 'package:nigoh_family_parent/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _signedIn = {
  'status': 'success',
  'token': 'ngh_ok',
  'user': {'id': 1, 'email': 'p@x.tj', 'full_name': 'Падар', 'role': 'parent'},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Session', () {
    test('login asks for the code, verifyOtp signs in', () async {
      final bodies = <String, Object?>{};
      final session = Session(
        api: NigohApi(
          client: MockClient((r) async {
            bodies[r.url.path] = r.body.isEmpty ? null : jsonDecode(r.body);
            if (r.url.path.endsWith('/auth/login')) {
              return _json({'status': 'otp_required', 'ticket': 't' * 30});
            }
            if (r.url.path.endsWith('/auth/login/otp')) return _json(_signedIn);
            return _json({});
          }),
        ),
      );
      expect(await session.login(' p@x.tj ', 'pass12345'), isFalse);
      expect(session.otpTicket, 't' * 30);
      expect(session.api.token, isNull, reason: 'no token before the code');
      await session.verifyOtp(' 123456 ');
      expect(session.api.token, 'ngh_ok');
      expect(session.otpTicket, isNull);
      expect(bodies['/api/mobile/v3/auth/login/otp'], {
        'ticket': 't' * 30,
        'code': '123456',
      });
    });

    test('wrong code keeps the ticket; lock clears it', () async {
      var status = 400;
      final session = Session(
        api: NigohApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/auth/login')) {
              return _json({'status': 'otp_required', 'ticket': 't' * 30});
            }
            return _json({'detail': 'Рамз нодуруст аст'}, status);
          }),
        ),
      );
      await session.login('p@x.tj', 'pass12345');
      await expectLater(
        session.verifyOtp('111111'),
        throwsA(isA<ApiException>()),
      );
      expect(session.otpTicket, isNotNull);
      status = 429;
      await expectLater(
        session.verifyOtp('111111'),
        throwsA(isA<ApiException>()),
      );
      expect(session.otpTicket, isNull);
      await expectLater(
        session.verifyOtp('111111'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Мӯҳлати рамз'),
          ),
        ),
      );
    });

    test('login without two-step signs in directly', () async {
      final session = Session(
        api: NigohApi(client: MockClient((r) async => _json(_signedIn))),
      );
      expect(await session.login('p@x.tj', 'pass12345'), isTrue);
      expect(session.api.token, 'ngh_ok');
    });

    test('email code: request, verify, then authenticator when on', () async {
      final calls = <String>[];
      var twoStep = false;
      final session = Session(
        api: NigohApi(
          client: MockClient((r) async {
            calls.add('${r.url.path} ${r.body}');
            if (r.url.path.endsWith('/email-code')) {
              return _json({'status': 'sent'});
            }
            if (r.url.path.endsWith('/email-code/verify')) {
              return twoStep
                  ? _json({'status': 'otp_required', 'ticket': 'e' * 30})
                  : _json(_signedIn);
            }
            return _json({});
          }),
        ),
      );
      await session.requestEmailCode(' P@X.tj ');
      expect(calls.last, contains('"email":"p@x.tj"'));
      expect(await session.verifyEmailCode('p@x.tj', '654321'), isTrue);
      expect(session.api.token, 'ngh_ok');
      twoStep = true;
      expect(await session.verifyEmailCode('p@x.tj', '654321'), isFalse);
      expect(session.otpTicket, 'e' * 30);
    });
  });

  group('AuthScreen', () {
    testWidgets('password then the code sheet signs the parent in', (
      tester,
    ) async {
      final session = Session(
        api: NigohApi(
          client: MockClient((r) async {
            final path = r.url.path;
            if (path.endsWith('/auth/otp/config')) {
              return _json({'totp': true, 'email': true});
            }
            if (path.endsWith('/auth/apple/config') ||
                path.endsWith('/auth/github/config')) {
              return _json({'enabled': false});
            }
            if (path.endsWith('/auth/login')) {
              return _json({'status': 'otp_required', 'ticket': 't' * 30});
            }
            if (path.endsWith('/auth/login/otp')) {
              final code = (jsonDecode(r.body) as Map)['code'];
              return code == '246810'
                  ? _json(_signedIn)
                  : _json({'detail': 'Рамз нодуруст аст'}, 400);
            }
            return _json({});
          }),
        ),
      );
      await session.load();
      await tester.pumpWidget(
        SessionScope(
          session: session,
          child: MaterialApp(
            theme: NigohTheme.light(),
            home: const AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth.email-code')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('auth.email')), 'p@x.tj');
      await tester.enterText(
        find.byKey(const Key('auth.password')),
        'pass12345',
      );
      await tester.ensureVisible(find.byKey(const Key('auth.submit')));
      await tester.tap(find.byKey(const Key('auth.submit')));
      await tester.pumpAndSettle();
      expect(find.text('Рамзи тасдиқ'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('otp-code')), '000000');
      await tester.tap(find.byKey(const ValueKey('otp-verify')));
      await tester.pumpAndSettle();
      expect(find.text('Рамз нодуруст аст'), findsOneWidget);
      expect(session.api.token, isNull);
      await tester.enterText(find.byKey(const ValueKey('otp-code')), '246810');
      await tester.tap(find.byKey(const ValueKey('otp-verify')));
      await tester.pumpAndSettle();
      expect(session.api.token, 'ngh_ok');
      expect(find.text('Рамзи тасдиқ'), findsNothing);
    });

    testWidgets('email-code button is hidden when the server has no SMTP', (
      tester,
    ) async {
      final session = Session(
        api: NigohApi(
          client: MockClient(
            (r) async => r.url.path.endsWith('/auth/otp/config')
                ? _json({'totp': true, 'email': false})
                : _json({'enabled': false}),
          ),
        ),
      );
      await session.load();
      await tester.pumpWidget(
        SessionScope(
          session: session,
          child: MaterialApp(
            theme: NigohTheme.light(),
            home: const AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth.email-code')), findsNothing);
    });
  });

  group('TwoStepScreen', () {
    testWidgets('turn on: QR, confirm, recovery codes; then turn off', (
      tester,
    ) async {
      var enabled = false;
      final posted = <String>[];
      final api = NigohApi(
        client: MockClient((r) async {
          final path = r.url.path;
          if (r.method == 'POST') {
            posted.add('${path.split('/').last} ${r.body}');
          }
          if (path.endsWith('/me/totp')) {
            return _json({
              'available': true,
              'enabled': enabled,
              'recovery_left': enabled ? 8 : 0,
            });
          }
          if (path.endsWith('/setup')) {
            return _json({
              'status': 'pending',
              'secret': 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
              'uri': 'otpauth://totp/NIGOH%20Family:p@x.tj?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
            });
          }
          if (path.endsWith('/confirm')) {
            enabled = true;
            return _json({
              'status': 'enabled',
              'available': true,
              'enabled': true,
              'recovery_left': 8,
              'recovery_codes': List.generate(8, (i) => 'AAAA-BBB$i'),
            });
          }
          if (path.endsWith('/disable')) {
            enabled = false;
            return _json({
              'status': 'disabled',
              'available': true,
              'enabled': false,
              'recovery_left': 0,
            });
          }
          return _json({});
        }),
      );
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: TwoStepScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Ҳимояи дуқабата хомӯш аст'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('two-step-start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('two-step-qr')), findsOneWidget);
      expect(
        find.text('JBSW Y3DP EHPK 3PXP JBSW Y3DP EHPK 3PXP'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('two-step-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('two-step-confirm')));
      await tester.pumpAndSettle();
      expect(posted.last, 'confirm {"code":"123456"}');
      expect(find.text('Рамзҳои эҳтиётиро нигоҳ доред'), findsOneWidget);
      expect(find.text('AAAA-BBB0'), findsOneWidget);
      expect(find.text('AAAA-BBB7'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('two-step-done')));
      await tester.pumpAndSettle();
      expect(find.text('Ҳимояи дуқабата фаъол аст'), findsOneWidget);
      expect(find.text('Рамзҳои эҳтиётии боқимонда: 8'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('two-step-code')),
        'AAAA-BBB1',
      );
      await tester.tap(find.byKey(const ValueKey('two-step-disable')));
      await tester.pumpAndSettle();
      expect(posted.last, 'disable {"code":"AAAA-BBB1"}');
      expect(find.text('Ҳимояи дуқабата хомӯш аст'), findsOneWidget);
    });

    testWidgets('server without the key says it is not set up', (tester) async {
      final api = NigohApi(
        client: MockClient(
          (r) async =>
              _json({'available': false, 'enabled': false, 'recovery_left': 0}),
        ),
      );
      await tester.pumpWidget(MaterialApp(home: TwoStepScreen(api: api)));
      await tester.pumpAndSettle();
      expect(
        find.text('Ин имконият дар сервер ҳоло танзим нашудааст.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('two-step-start')), findsNothing);
    });
  });
}
