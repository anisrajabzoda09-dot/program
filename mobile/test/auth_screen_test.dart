import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/auth/auth_screen.dart';
import 'package:nigoh_family_parent/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<http.Request> requests;

  Future<Session> pumpAuth(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    requests = [];
    final session = Session(
      api: NigohApi(
        client: MockClient((request) {
          // The Apple/GitHub configs fetched on screen open are covered by
          // apple_sign_in_test.dart and github_sign_in_test.dart.
          if (!request.url.path.endsWith('/auth/apple/config') &&
              !request.url.path.endsWith('/auth/github/config') &&
              !request.url.path.endsWith('/auth/otp/config')) {
            requests.add(request);
          }
          return handler(request);
        }),
      ),
    );
    await session.load();
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: MaterialApp(theme: NigohTheme.light(), home: const AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders title, form and Google button', (tester) async {
    await pumpAuth(tester, (_) async => http.Response('{}', 200));
    expect(find.text('NIGOH Family'), findsOneWidget);
    expect(find.text('Идома бо Google'), findsOneWidget);
    expect(find.byKey(const Key('auth.email')), findsOneWidget);
    expect(find.byKey(const Key('auth.name')), findsNothing);
    expect(
      find.text(
        'Агар пештар бо почта ворид мешудед, як бор аз нав бақайдгирӣ кунед.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('validates email and password before calling the server', (
    tester,
  ) async {
    await pumpAuth(tester, (_) async => http.Response('{}', 200));
    await tester.ensureVisible(find.byKey(const Key('auth.submit')));
    await tester.tap(find.byKey(const Key('auth.submit')));
    await tester.pump();
    expect(find.text('Почтаро нависед.'), findsOneWidget);
    expect(find.text('Рамзро нависед.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth.email')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('auth.password')), 'short');
    await tester.ensureVisible(find.byKey(const Key('auth.submit')));
    await tester.tap(find.byKey(const Key('auth.submit')));
    await tester.pump();
    expect(find.text('Почтаи электронӣ нодуруст аст.'), findsOneWidget);
    expect(find.text('Рамз бояд ақаллан 8 аломат бошад.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('register mode asks for a name', (tester) async {
    await pumpAuth(tester, (_) async => http.Response('{}', 200));
    await tester.tap(find.text('Бақайдгирӣ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth.name')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('auth.submit')));
    await tester.tap(find.byKey(const Key('auth.submit')));
    await tester.pump();
    expect(find.text('Номро нависед.'), findsOneWidget);
  });

  testWidgets('shows the server error detail on failed login', (tester) async {
    final session = await pumpAuth(
      tester,
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'detail': 'Почта ё рамз нодуруст аст.'})),
        401,
      ),
    );
    await tester.enterText(find.byKey(const Key('auth.email')), 'a@b.tj');
    await tester.enterText(find.byKey(const Key('auth.password')), 'secret123');
    await tester.ensureVisible(find.byKey(const Key('auth.submit')));
    await tester.tap(find.byKey(const Key('auth.submit')));
    await tester.pumpAndSettle();

    expect(requests.single.url.path, '/api/mobile/v3/auth/login');
    expect(find.text('Почта ё рамз нодуруст аст.'), findsOneWidget);
    expect(session.signedIn, isFalse);
  });

  testWidgets('successful login signs the session in', (tester) async {
    final session = await pumpAuth(
      tester,
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'token': 'ngh_t',
            'user': {'full_name': 'Модар', 'email': 'a@b.tj'},
          }),
        ),
        200,
      ),
    );
    await tester.enterText(find.byKey(const Key('auth.email')), 'a@b.tj');
    await tester.enterText(find.byKey(const Key('auth.password')), 'secret123');
    await tester.ensureVisible(find.byKey(const Key('auth.submit')));
    await tester.tap(find.byKey(const Key('auth.submit')));
    await tester.pumpAndSettle();
    expect(session.signedIn, isTrue);
  });
}
