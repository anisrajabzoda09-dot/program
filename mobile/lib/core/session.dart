// Sign-in session: token, user and role persisted in shared preferences,
// plus the inherited widget that exposes it to the widget tree.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import '../l10n/l10n.dart';

/// Google OAuth web client ID the server uses to verify Google ID tokens.
const googleServerClientId = String.fromEnvironment(
  'NIGOH_GOOGLE_WEB_CLIENT_ID',
  defaultValue: '708817646656-mdjfklgfsfaq83h9q5fa0j1mr74avo03.apps.googleusercontent.com',
);

/// Gets an Apple ID credential for [nonce] (already sha256-hashed) through
/// the given web flow; replaced in tests so they don't need the plugin.
typedef AppleCredentialProvider =
    Future<AuthorizationCredentialAppleID> Function({
      required String nonce,
      required WebAuthenticationOptions webAuthenticationOptions,
    });

/// Default [AppleCredentialProvider]: the sign_in_with_apple plugin (Chrome
/// Custom Tab on Android), asking for email and name.
Future<AuthorizationCredentialAppleID> pluginAppleCredential({
  required String nonce,
  required WebAuthenticationOptions webAuthenticationOptions,
}) => SignInWithApple.getAppleIDCredential(
  scopes: const [
    AppleIDAuthorizationScopes.email,
    AppleIDAuthorizationScopes.fullName,
  ],
  nonce: nonce,
  webAuthenticationOptions: webAuthenticationOptions,
);

/// Opens [url] in a browser tab and resolves with the callback URL the server
/// redirects to (scheme [callbackUrlScheme]); replaced in tests.
typedef GitHubBrowserAuth =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
    });

/// Default [GitHubBrowserAuth]: the flutter_web_auth_2 plugin (Custom Tab).
Future<String> pluginGitHubBrowser({
  required String url,
  required String callbackUrlScheme,
}) => FlutterWebAuth2.authenticate(
  url: url,
  callbackUrlScheme: callbackUrlScheme,
);

/// Thrown when the user backs out of GitHub sign-in; the screen stays silent.
class GitHubSignInCancelled implements Exception {
  const GitHubSignInCancelled();

  @override
  String toString() => 'GitHub sign-in cancelled';
}

/// Random raw nonce for one Apple sign-in (Random.secure, URL-safe chars).
String appleRawNonce([int length = 48]) => secureRawNonce(length);

/// Random raw nonce for one Apple/GitHub sign-in (Random.secure, URL-safe).
String secureRawNonce([int length = 48]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

/// Hex sha256 of [raw]; Apple gets this, the server gets the raw value.
String sha256Hex(String raw) => sha256.convert(utf8.encode(raw)).toString();

/// Signed-in state of the app. One instance lives for the whole app
/// (see `SessionScope`). Screens read [user]/[role] and call the actions.
class Session extends ChangeNotifier {
  Session({
    NigohApi? api,
    AppleCredentialProvider? appleCredential,
    GitHubBrowserAuth? githubBrowser,
  }) : api = api ?? NigohApi(),
       appleCredential = appleCredential ?? pluginAppleCredential,
       githubBrowser = githubBrowser ?? pluginGitHubBrowser {
    this.api.onUnauthorized = _expired;
  }

  final NigohApi api;

  /// Where Apple ID credentials come from (the plugin, or a fake in tests).
  final AppleCredentialProvider appleCredential;

  /// Opens the GitHub browser flow (the plugin, or a fake in tests).
  final GitHubBrowserAuth githubBrowser;

  static const _tokenKey = 'nigoh.token';
  static const _roleKey = 'nigoh.role';
  static const _userKey = 'nigoh.user';

  bool loading = true;
  Map<String, dynamic>? user;

  /// 'parent' | 'child' | null (not chosen yet on this phone).
  String? role;

  bool get signedIn => api.token != null;
  bool get isParent => role == 'parent';
  bool get isChild => role == 'child';
  String get displayName => user?['full_name']?.toString() ?? '';
  String get email => user?['email']?.toString() ?? '';

  /// Server path of the profile photo (see `NigohApi.fileUrl`), or null.
  String? get avatar {
    final value = user?['avatar']?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  /// Updates the cached profile after an avatar upload/delete.
  void setAvatar(String? path) {
    user = {...?user, 'avatar': path};
    notifyListeners();
  }

  /// Restores the saved token, role and name at app start.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString(_tokenKey);
    role = prefs.getString(_roleKey);
    api.role = role;
    final cachedName = prefs.getString(_userKey);
    if (cachedName != null) user = {'full_name': cachedName};
    loading = false;
    notifyListeners();
    if (api.token != null) unawaitedRefresh();
  }

  /// Refresh the profile in the background; offline is fine.
  void unawaitedRefresh() {
    api
        .me()
        .then((data) {
          final fresh = data['user'];
          if (fresh is Map) {
            user = Map<String, dynamic>.from(fresh);
            _saveName();
            notifyListeners();
          }
        })
        .catchError((_) {});
  }

  /// Saves the token and user returned by a successful sign-in.
  Future<void> _store(Map<String, dynamic> response) async {
    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(tr('Сервер токен надод. Аз нав кӯшиш кунед.'));
    }
    api.token = token;
    final u = response['user'];
    user = u is Map ? Map<String, dynamic>.from(u) : <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await _saveName();
    notifyListeners();
  }

  /// Caches the display name so it shows before the server answers.
  Future<void> _saveName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, displayName);
  }

  Future<void> register(String email, String password, String name) async =>
      _store(await api.register(email.trim(), password, name.trim()));

  Future<void> login(String email, String password) async =>
      _store(await api.login(email.trim(), password));

  /// Google sign-in; the server verifies the ID token itself.
  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    await google.initialize(serverClientId: googleServerClientId);
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw ApiException(tr('Google токен надод. Аз нав кӯшиш кунед.'));
    }
    await _store(await api.google(idToken));
  }

  /// Sign in with Apple via the server's web-flow bridge. Throws
  /// [SignInWithAppleAuthorizationException] (code `canceled` when the user
  /// backs out) or a readable [ApiException]. [onCredential] fires once Apple
  /// has answered, before the server is asked.
  Future<void> signInWithApple({void Function()? onCredential}) async {
    final config = await api.appleConfig();
    if (!config.enabled) {
      throw ApiException(tr('Воридшавӣ бо Apple ҳоло дастрас нест.'));
    }
    final rawNonce = appleRawNonce();
    final credential = await appleCredential(
      nonce: sha256Hex(rawNonce),
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: config.clientId!,
        redirectUri: Uri.parse(config.redirectUri!),
      ),
    );
    onCredential?.call();
    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw ApiException(tr('Apple токен надод. Аз нав кӯшиш кунед.'));
    }
    final fullName = [credential.givenName, credential.familyName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    await _store(
      await api.signInWithApple(
        identityToken: identityToken,
        nonce: rawNonce,
        fullName: fullName.isEmpty ? null : fullName,
      ),
    );
  }

  /// Sign in with GitHub via the server's browser flow: the tab gets the
  /// nonce's sha256, the server gets the one-time ticket plus the RAW nonce.
  /// Throws [GitHubSignInCancelled] when the user backs out, otherwise a
  /// readable [ApiException].
  Future<void> signInWithGitHub() async {
    final config = await api.githubConfig();
    if (!config.enabled) {
      throw ApiException(tr('Воридшавӣ бо GitHub ҳоло дастрас нест.'));
    }
    final rawNonce = secureRawNonce();
    final start = Uri.parse(config.startUrl!);
    final url = start.replace(
      queryParameters: {
        ...start.queryParameters,
        'nonce_hash': sha256Hex(rawNonce),
      },
    );
    final String result;
    try {
      result = await githubBrowser(
        url: url.toString(),
        callbackUrlScheme: config.callbackScheme!,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw const GitHubSignInCancelled();
      throw ApiException(tr('Воридшавӣ бо GitHub нашуд. Аз нав кӯшиш кунед.'));
    }
    final ticket = _githubTicket(result);
    await _store(await api.signInWithGitHub(ticket: ticket, nonce: rawNonce));
  }

  /// Pulls the ticket out of the GitHub callback URL or throws the matching
  /// cancel / readable error.
  String _githubTicket(String callbackUrl) {
    final params = Uri.tryParse(callbackUrl)?.queryParameters ?? const {};
    final ticket = params['ticket'] ?? '';
    final error = params['error'];
    if (error == null && ticket.isNotEmpty) return ticket;
    switch (error) {
      case 'cancelled':
      case 'canceled':
        throw const GitHubSignInCancelled();
      case 'no_email':
        throw ApiException(
          tr(
            'GitHub почтаи тасдиқшударо надод. Почтаи худро дар GitHub тасдиқ кунед ва аз нав кӯшиш кунед.',
          ),
        );
      case 'not_configured':
        throw ApiException(tr('Воридшавӣ бо GitHub ҳоло дастрас нест.'));
      default:
        throw ApiException(tr('Воридшавӣ бо GitHub нашуд. Аз нав кӯшиш кунед.'));
    }
  }

  /// Saves the role chosen for this phone and tells the server about it.
  Future<void> chooseRole(String value) async {
    role = value;
    api.role = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, value);
    notifyListeners();
    try {
      await api.updateMe(role: value);
    } catch (_) {
      // The role header on every request is what the server acts on.
    }
  }

  /// Renames the signed-in user on the server and caches the new name.
  Future<void> updateName(String name) async {
    final data = await api.updateMe(fullName: name.trim());
    final fresh = data['user'];
    if (fresh is Map) user = Map<String, dynamic>.from(fresh);
    await _saveName();
    notifyListeners();
  }

  /// Signs out on the server and from Google, then forgets the local session.
  Future<void> signOut() async {
    try {
      await api.logout();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _clear();
  }

  /// Called when the server rejects the token: signs out locally.
  void _expired() {
    if (api.token == null) return;
    _clear();
  }

  /// Forgets the token, user and role locally and notifies listeners.
  Future<void> _clear() async {
    api.token = null;
    user = null;
    role = null;
    api.role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }
}

/// Gives every screen access to the [Session]: `SessionScope.of(context)`.
/// Widgets that call `of` rebuild when the session changes.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({
    super.key,
    required Session session,
    required super.child,
  }) : super(notifier: session);

  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Read without subscribing to changes (for callbacks).
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
