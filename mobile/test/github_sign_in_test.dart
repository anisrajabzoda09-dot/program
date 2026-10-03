// Файл: санҷишҳои «Идома бо GitHub» дар экрани воридшавӣ — тугма аз рӯи
// танзимоти сервер, nonce-и хом ба сервер ва ҳэши он ба браузер, бекоркунӣ
// хомӯш, хатоҳо бо паёми фаҳмо.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/auth/auth_screen.dart';
import 'package:nigoh_family_parent/ui/github_mark.dart';
import 'package:nigoh_family_parent/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Санҷишҳои тугмаи GitHub ва Session.signInWithGitHub.
void main() {
  late List<http.Request> requests;
  late List<Uri> opened;
  late List<String> schemes;

  /// Ҷавоби JSON (UTF-8, то матни тоҷикӣ вайрон нашавад).
  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status);

  const enabledConfig = {
    'enabled': true,
    'start_url': 'https://nigohfamily.qobus.tj/auth/github/mobile',
    'callback_scheme': 'nigohfamily',
  };

  /// Экрани воридшавиро бо сервери қалбакӣ ва браузери қалбакии GitHub месозад.
  Future<Session> pump(
    WidgetTester tester, {
    required Map<String, Object?> config,
    int configStatus = 200,
    Future<String> Function(Uri url)? browser,
    Future<http.Response> Function(http.Request)? onSignIn,
  }) async {
    requests = [];
    opened = [];
    schemes = [];
    final session = Session(
      api: NigohApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/mobile/v3/auth/apple/config') {
            return json({
              'enabled': false,
              'client_id': null,
              'redirect_uri': null,
            });
          }
          requests.add(request);
          if (request.url.path == '/api/mobile/v3/auth/github/config') {
            return json(config, configStatus);
          }
          if (request.url.path == '/api/mobile/v3/auth/github') {
            return onSignIn!(request);
          }
          return json({}, 404);
        }),
      ),
      githubBrowser: ({required url, required callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        opened.add(uri);
        schemes.add(callbackUrlScheme);
        return (browser ??
            (_) async =>
                'nigohfamily://auth/github?ticket=TICKET-0123456789abcdef')(
          uri,
        );
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

  /// Тугмаи GitHub-ро пахш мекунад ва то анҷоми воридшавӣ интизор мешавад.
  Future<void> tapGitHub(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('auth.github')));
    await tester.tap(find.byKey(const Key('auth.github')));
    await tester.pumpAndSettle();
  }

  /// Ҷавоби муваффақи сервер барои билет.
  Future<http.Response> ok(http.Request _) async => json({
    'status': 'success',
    'token': 'ngh_github',
    'user': {'full_name': 'Test Dev', 'email': 'dev@example.com'},
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('button hidden when the server disables GitHub', (tester) async {
    await pump(
      tester,
      config: {'enabled': false, 'start_url': null, 'callback_scheme': null},
    );
    expect(find.byKey(const Key('auth.github')), findsNothing);
    expect(find.text('Идома бо Google'), findsOneWidget);
  });

  testWidgets('button hidden when the config request fails', (tester) async {
    await pump(tester, config: {'detail': 'x'}, configStatus: 500);
    expect(find.byKey(const Key('auth.github')), findsNothing);
  });

  testWidgets('button shown with the GitHub mark when enabled', (tester) async {
    await pump(tester, config: enabledConfig);
    expect(find.text('Идома бо GitHub'), findsOneWidget);
    expect(find.byType(GitHubMark), findsOneWidget);
  });

  testWidgets('browser gets sha256(nonce); server gets ticket + RAW nonce', (
    tester,
  ) async {
    await pump(tester, config: enabledConfig, onSignIn: ok);
    await tapGitHub(tester);

    expect(schemes, ['nigohfamily']);
    final url = opened.single;
    expect(url.host, 'nigohfamily.qobus.tj');
    expect(url.path, '/auth/github/mobile');
    final post = requests.last;
    expect(post.method, 'POST');
    expect(post.url.path, '/api/mobile/v3/auth/github');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    final raw = body['nonce'] as String;
    expect(raw.length, greaterThanOrEqualTo(32));
    expect(url.queryParameters['nonce_hash'], sha256Hex(raw));
    expect(body['ticket'], 'TICKET-0123456789abcdef');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nigoh.token'), 'ngh_github');
  });

  testWidgets('each attempt uses a fresh nonce', (tester) async {
    await pump(
      tester,
      config: enabledConfig,
      browser: (_) async => 'nigohfamily://auth/github?error=cancelled',
    );
    await tapGitHub(tester);
    await tapGitHub(tester);
    expect(opened.length, 2);
    expect(
      opened[0].queryParameters['nonce_hash'],
      isNot(opened[1].queryParameters['nonce_hash']),
    );
  });

  testWidgets('cancel in the browser is silent and posts nothing', (
    tester,
  ) async {
    await pump(
      tester,
      config: enabledConfig,
      browser: (_) async => 'nigohfamily://auth/github?error=cancelled',
    );
    await tapGitHub(tester);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('closing the browser tab (plugin CANCELED) is silent', (
    tester,
  ) async {
    await pump(
      tester,
      config: enabledConfig,
      browser: (_) async => throw PlatformException(code: 'CANCELED'),
    );
    await tapGitHub(tester);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth.github')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('no verified e-mail tells the user to verify it on GitHub', (
    tester,
  ) async {
    await pump(
      tester,
      config: enabledConfig,
      browser: (_) async => 'nigohfamily://auth/github?error=no_email',
    );
    await tapGitHub(tester);
    expect(
      find.textContaining('Почтаи худро дар GitHub тасдиқ кунед'),
      findsOneWidget,
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('server 401 shows its message', (tester) async {
    await pump(
      tester,
      config: enabledConfig,
      onSignIn: (_) async =>
          json({'detail': 'Воридшавӣ бо GitHub тасдиқ нашуд'}, 401),
    );
    await tapGitHub(tester);
    expect(find.text('Воридшавӣ бо GitHub тасдиқ нашуд'), findsOneWidget);
  });
}
