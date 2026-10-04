// Файл: session, token, нақш ва ҳолати воридшавӣ.

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

/// Қимати googleServerClientId-ро барои session, token, нақш ва ҳолати воридшавӣ нигоҳ медорад.
const googleServerClientId = String.fromEnvironment(
  'NIGOH_GOOGLE_WEB_CLIENT_ID',
  defaultValue: '708817646656-mdjfklgfsfaq83h9q5fa0j1mr74avo03.apps.googleusercontent.com',
);

/// Шакли callback-и истифодашавандаро барои session, token, нақш ва ҳолати воридшавӣ муайян мекунад.
typedef AppleCredentialProvider =
    /// Function мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
    Future<AuthorizationCredentialAppleID> Function({
      required String nonce,
      required WebAuthenticationOptions webAuthenticationOptions,
    });

/// pluginAppleCredential мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
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

/// Шакли callback-и истифодашавандаро барои session, token, нақш ва ҳолати воридшавӣ муайян мекунад.
typedef GitHubBrowserAuth =
    /// Function мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
    });

/// pluginGitHubBrowser мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
Future<String> pluginGitHubBrowser({
  required String url,
  required String callbackUrlScheme,
}) => FlutterWebAuth2.authenticate(
  url: url,
  callbackUrlScheme: callbackUrlScheme,
);

/// Додаҳо ва рафтори марбут ба session, token, нақш ва ҳолати воридшавӣро ифода мекунад.
class GitHubSignInCancelled implements Exception {
  const GitHubSignInCancelled();

  /// Намоиши матнии GitHubSignInCancelled-ро барои log бармегардонад.
  @override
  String toString() => 'GitHub sign-in cancelled';
}

/// appleRawNonce мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
String appleRawNonce([int length = 48]) => secureRawNonce(length);

/// secureRawNonce мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
String secureRawNonce([int length = 48]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

/// sha256Hex мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
String sha256Hex(String raw) => sha256.convert(utf8.encode(raw)).toString();

/// Додаҳо ва рафтори марбут ба session, token, нақш ва ҳолати воридшавӣро ифода мекунад.
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

  /// Қимати appleCredential-ро барои session, token, нақш ва ҳолати воридшавӣ нигоҳ медорад.
  final AppleCredentialProvider appleCredential;

  /// Қимати githubBrowser-ро барои session, token, нақш ва ҳолати воридшавӣ нигоҳ медорад.
  final GitHubBrowserAuth githubBrowser;

  static const _tokenKey = 'nigoh.token';
  static const _roleKey = 'nigoh.role';
  static const _userKey = 'nigoh.user';

  bool loading = true;
  Map<String, dynamic>? user;

  /// Қимати role-ро барои session, token, нақш ва ҳолати воридшавӣ нигоҳ медорад.
  String? role;

  /// Қимати ҳисобшудаи signedIn-ро аз ҳолати ҷорӣ бармегардонад.
  bool get signedIn => api.token != null;
  /// Қимати ҳисобшудаи isParent-ро аз ҳолати ҷорӣ бармегардонад.
  bool get isParent => role == 'parent';
  /// Қимати ҳисобшудаи isChild-ро аз ҳолати ҷорӣ бармегардонад.
  bool get isChild => role == 'child';
  /// Қимати ҳисобшудаи displayName-ро аз ҳолати ҷорӣ бармегардонад.
  String get displayName => user?['full_name']?.toString() ?? '';
  /// Қимати ҳисобшудаи email-ро аз ҳолати ҷорӣ бармегардонад.
  String get email => user?['email']?.toString() ?? '';

  /// Қимати ҳисобшудаи avatar-ро барои session, token, нақш ва ҳолати воридшавӣ бармегардонад.
  String? get avatar {
    final value = user?['avatar']?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  /// setAvatar ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  void setAvatar(String? path) {
    user = {...?user, 'avatar': path};
    notifyListeners();
  }

  /// load додаҳои session-ро мехонад ва ҳолати Session-ро нав мекунад.
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

  /// unawaitedRefresh мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
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

  /// store тағйиротро барои истифодаи баъдӣ нигоҳ медорад.
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

  /// saveName тағйиротро барои истифодаи баъдӣ нигоҳ медорад.
  Future<void> _saveName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, displayName);
  }

  /// register дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> register(String email, String password, String name) async =>
      _store(await api.register(email.trim(), password, name.trim()));

  /// Чиптаи қадами дуюм: парол ё рамзи почта дуруст буд, акнун рамзи Authenticator лозим.
  String? otpTicket;

  /// Бо почта ва парол ворид мешавад. false — агар рамзи Authenticator лозим бошад.
  Future<bool> login(String email, String password) async =>
      _finishFirstStep(await api.login(email.trim(), password));

  /// Ҷавоби қадами аввалро коркард мекунад: token-ро нигоҳ медорад ё чиптаро.
  Future<bool> _finishFirstStep(Map<String, dynamic> response) async {
    if (response['status'] == 'otp_required') {
      otpTicket = response['ticket']?.toString();
      return false;
    }
    otpTicket = null;
    await _store(response);
    return true;
  }

  /// Қадами дуюм: рамзи 6-рақама ё рамзи эҳтиётӣ.
  Future<void> verifyOtp(String code) async {
    final ticket = otpTicket;
    if (ticket == null) {
      throw ApiException(tr('Мӯҳлати рамз гузашт. Аз нав ворид шавед'));
    }
    try {
      await _store(await api.loginOtp(ticket, code.trim()));
      otpTicket = null;
    } on ApiException catch (e) {
      // Чипта беэътибор шуд (мӯҳлат ё қулф) — бояд аз нав парол ворид шавад.
      if (e.statusCode == 401 || e.statusCode == 429) otpTicket = null;
      rethrow;
    }
  }

  /// Рамзи воридшавиро ба почта мефиристад.
  Future<void> requestEmailCode(String email) =>
      api.requestEmailCode(email.trim().toLowerCase());

  /// Бо рамзи почта ворид мешавад. false — агар баъд рамзи Authenticator лозим бошад.
  Future<bool> verifyEmailCode(String email, String code) async =>
      _finishFirstStep(
        await api.verifyEmailCode(email.trim().toLowerCase(), code.trim()),
      );

  /// signInWithGoogle мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
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

  /// signInWithApple мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
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

  /// signInWithGitHub мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
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

  /// githubTicket мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
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

  /// chooseRole ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> chooseRole(String value) async {
    role = value;
    api.role = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, value);
    notifyListeners();
    try {
      await api.updateMe(role: value);
    } catch (_) {
      // Ин қадам ҷавоби server ё хатои API-ро коркард мекунад.
    }
  }

  /// updateName ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> updateName(String name) async {
    final data = await api.updateMe(fullName: name.trim());
    final fresh = data['user'];
    if (fresh is Map) user = Map<String, dynamic>.from(fresh);
    await _saveName();
    notifyListeners();
  }

  /// signOut мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
  Future<void> signOut() async {
    try {
      await api.logout();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _clear();
  }

  /// expired мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
  void _expired() {
    if (api.token == null) return;
    _clear();
  }

  /// clear маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
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

/// Додаҳо ва рафтори марбут ба session, token, нақш ва ҳолати воридшавӣро ифода мекунад.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({
    super.key,
    required Session session,
    required super.child,
  }) : super(notifier: session);

  /// of мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад.
  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// read додаҳоро мехонад ва ҳолати экранро нав мекунад.
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
