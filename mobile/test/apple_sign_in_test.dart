// Sign in with Apple: the button follows the server config, the RAW nonce goes
// to the server while Apple gets its sha256, cancel is silent, 401 is shown.

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
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Tests for the Apple button on the sign-in screen and Session.signInWithApple.
void main() {
  late List<http.Request> requests;
  late List<String> providerNonces;
  late List<WebAuthenticationOptions> providerOptions;

  /// JSON reply helper (UTF-8 so Tajik text survives).
  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status);

  const enabledConfig = {
    'enabled': true,
    'client_id': 'tj.qobus.nigohfamily.web',
    'redirect_uri': 'https://nigohfamily.qobus.tj/auth/apple/android',
  };

  /// Fake Apple credential carrying the given nonce in a fake token.
  AuthorizationCredentialAppleID credential(String nonce) =>
      AuthorizationCredentialAppleID(
        userIdentifier: null,
        givenName: 'Модар',
        familyName: 'Раҷабова',
        email: 'a@privaterelay.appleid.com',
        authorizationCode: 'code',
        identityToken: 'apple.jwt.$nonce',
        state: null,
      );

  /// Pumps AuthScreen with a fake server and a fake Apple provider.
  Future<Session> pump(
    WidgetTester tester, {
    required Map<String, Object?> config,
    Future<http.Response> Function(http.Request)? onSignIn,
    Future<AuthorizationCredentialAppleID> Function(String nonce)? provider,
    int configStatus = 200,
  }) async {
    requests = [];
    providerNonces = [];
    providerOptions = [];
    final session = Session(
      api: NigohApi(
        client: MockClient((request) async {
          // The GitHub config call is covered by github_sign_in_test.dart.
          if (request.url.path == '/api/mobile/v3/auth/github/config') {
            return json({
              'enabled': false,
              'start_url': null,
              'callback_scheme': null,
            });
          }
          // The two-step config call is covered by two_step_test.dart.
          if (request.url.path == '/api/mobile/v3/auth/otp/config') {
            return json({'totp': false, 'email': false});
          }
          requests.add(request);
          if (request.url.path == '/api/mobile/v3/auth/apple/config') {
            return json(config, configStatus);
          }
          if (request.url.path == '/api/mobile/v3/auth/apple') {
            return onSignIn!(request);
          }
          return json({}, 404);
        }),
      ),
      appleCredential:
          ({required nonce, required webAuthenticationOptions}) async {
            providerNonces.add(nonce);
            providerOptions.add(webAuthenticationOptions);
            return (provider ?? (n) async => credential(n))(nonce);
          },
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

  /// Taps the Apple button and waits for the sign-in to finish.
  Future<void> tapApple(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('auth.apple')));
    await tester.tap(find.byKey(const Key('auth.apple')));
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('button hidden when the server disables Apple', (tester) async {
    await pump(
      tester,
      config: {'enabled': false, 'client_id': null, 'redirect_uri': null},
    );
    expect(requests.single.url.path, '/api/mobile/v3/auth/apple/config');
    expect(find.text('Идома бо Apple'), findsNothing);
    expect(find.text('Идома бо Google'), findsOneWidget);
  });

  testWidgets('button hidden when the config request fails', (tester) async {
    await pump(tester, config: {'detail': 'x'}, configStatus: 500);
    expect(find.byKey(const Key('auth.apple')), findsNothing);
  });

  testWidgets('button shown when enabled', (tester) async {
    await pump(tester, config: enabledConfig);
    expect(find.text('Идома бо Apple'), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);
  });

  testWidgets('sends identity token and RAW nonce; Apple got its sha256', (
    tester,
  ) async {
    final session = await pump(
      tester,
      config: enabledConfig,
      onSignIn: (_) async => json({
        'status': 'ok',
        'token': 'ngh_apple',
        'user': {'full_name': 'Модар Раҷабова', 'email': 'a@b.tj'},
      }),
    );
    await tapApple(tester);

    final post = requests.last;
    expect(post.method, 'POST');
    expect(post.url.path, '/api/mobile/v3/auth/apple');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    final raw = body['nonce'] as String;
    expect(raw.length, greaterThanOrEqualTo(32));
    expect(providerNonces, [sha256Hex(raw)]);
    expect(raw, isNot(providerNonces.single));
    expect(body['identity_token'], 'apple.jwt.${providerNonces.single}');
    expect(body['full_name'], 'Модар Раҷабова');
    expect(providerOptions.single.clientId, 'tj.qobus.nigohfamily.web');
    expect(
      providerOptions.single.redirectUri,
      Uri.parse('https://nigohfamily.qobus.tj/auth/apple/android'),
    );
    expect(session.signedIn, isTrue);
    expect(session.api.token, 'ngh_apple');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nigoh.token'), 'ngh_apple');
  });

  testWidgets('each attempt uses a fresh nonce', (tester) async {
    await pump(
      tester,
      config: enabledConfig,
      onSignIn: (_) async => json({'detail': 'Нашуд'}, 401),
    );
    await tapApple(tester);
    await tester.pump(const Duration(seconds: 5));
    await tapApple(tester);
    expect(providerNonces, hasLength(2));
    expect(providerNonces.toSet(), hasLength(2));
  });

  testWidgets('cancel shows no error and stays signed out', (tester) async {
    final session = await pump(
      tester,
      config: enabledConfig,
      provider: (_) async => throw const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.canceled,
        message: 'User canceled authorization',
      ),
    );
    await tapApple(tester);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      requests.where((r) => r.url.path == '/api/mobile/v3/auth/apple'),
      isEmpty,
    );
    expect(session.signedIn, isFalse);
    // Button is usable again.
    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('auth.apple')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('server 401 shows the error detail', (tester) async {
    final session = await pump(
      tester,
      config: enabledConfig,
      onSignIn: (_) async =>
          json({'detail': 'Токени Apple нодуруст аст.'}, 401),
    );
    await tapApple(tester);
    expect(find.text('Токени Apple нодуруст аст.'), findsOneWidget);
    expect(session.signedIn, isFalse);
  });

  test('Session throws a friendly error when Apple is disabled', () async {
    final session = Session(
      api: NigohApi(
        client: MockClient(
          (_) async =>
              json({'enabled': false, 'client_id': null, 'redirect_uri': null}),
        ),
      ),
      appleCredential: ({required nonce, required webAuthenticationOptions}) =>
          throw StateError('must not be called'),
    );
    await expectLater(
      session.signInWithApple(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Воридшавӣ бо Apple ҳоло дастрас нест.',
        ),
      ),
    );
  });

  test('raw nonces are long, random and URL-safe', () {
    final a = appleRawNonce();
    final b = appleRawNonce();
    expect(a.length, greaterThanOrEqualTo(32));
    expect(a, isNot(b));
    expect(RegExp(r'^[A-Za-z0-9\-._]+$').hasMatch(a), isTrue);
    expect(
      sha256Hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
