import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'platform.dart';
import '../l10n/l10n.dart';

const googleServerClientId = String.fromEnvironment(
  'NIGOH_GOOGLE_WEB_CLIENT_ID',
  defaultValue: '708817646656-mdjfklgfsfaq83h9q5fa0j1mr74avo03.apps.googleusercontent.com',
);

/// Signed-in state of the app. One instance lives for the whole app
/// (see `SessionScope`). Screens read [user]/[role] and call the actions.
class Session extends ChangeNotifier {
  Session({NigohApi? api}) : api = api ?? NigohApi() {
    this.api.onUnauthorized = _expired;
  }

  final NigohApi api;

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

  Future<void> _saveName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, displayName);
  }

  Future<void> register(String email, String password, String name) async =>
      _store(await api.register(email.trim(), password, name.trim()));

  Future<void> login(String email, String password) async =>
      _store(await api.login(email.trim(), password));

  /// Google sign-in; the server verifies the ID token itself.
  /// Google sign-in has no Windows/desktop implementation.
  static bool get googleAvailable => !isDesktop;

  Future<void> signInWithGoogle() async {
    if (!googleAvailable) {
      throw ApiException(tr('Дар компютер бо почта ва рамз ворид шавед.'));
    }
    final google = GoogleSignIn.instance;
    await google.initialize(serverClientId: googleServerClientId);
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw ApiException(tr('Google токен надод. Аз нав кӯшиш кунед.'));
    }
    await _store(await api.google(idToken));
  }

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

  Future<void> updateName(String name) async {
    final data = await api.updateMe(fullName: name.trim());
    final fresh = data['user'];
    if (fresh is Map) user = Map<String, dynamic>.from(fresh);
    await _saveName();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.logout();
    } catch (_) {}
    if (googleAvailable) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _clear();
  }

  void _expired() {
    if (api.token == null) return;
    _clear();
  }

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
