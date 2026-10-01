import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const nigohApiBaseUrl = String.fromEnvironment(
  'NIGOH_API_BASE_URL',
  defaultValue: 'https://nigohfamily.qobus.tj',
);

/// Error with a message that can be shown to the user as-is (Tajik).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get unauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// HTTP client for the NIGOH server. No Firebase: the server issues an opaque
/// bearer token at sign-in. Every failure becomes an [ApiException] with a
/// readable message — callers should show it, never swallow it silently.
class NigohApi {
  NigohApi({http.Client? client, this.baseUrl = nigohApiBaseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  /// Session token (`ngh_…`); set by [Session].
  String? token;

  /// 'parent' or 'child' — the side this phone acts for.
  String? role;

  /// Called when the server rejects the token (signed out elsewhere/expired).
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'X-NIGOH-Device': 'android',
        if (body != null) 'Content-Type': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
        if (role != null) 'X-NIGOH-Role': role!,
      });
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('Сервер ҷавоб надод. Интернетро санҷед.');
    } on SocketException {
      throw const ApiException('Интернет нест. Пайвастшавиро санҷед.');
    } on http.ClientException {
      throw const ApiException('Пайвастшавӣ ба сервер нашуд.');
    }
    Map<String, dynamic> decoded = const {};
    if (response.body.isNotEmpty) {
      try {
        final raw = jsonDecode(utf8.decode(response.bodyBytes));
        if (raw is Map) decoded = Map<String, dynamic>.from(raw);
      } catch (_) {
        // Non-JSON (e.g. proxy error page) — handled below by status code.
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (response.statusCode == 401 && auth) onUnauthorized?.call();
    throw ApiException(
      _detail(decoded['detail']) ??
          'Хатогӣ дар сервер (${response.statusCode}). Баъдтар кӯшиш кунед.',
      statusCode: response.statusCode,
    );
  }

  static String? _detail(Object? detail) {
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      final loc = first is Map ? (first['loc'] as List?)?.last : null;
      if (loc == 'password') return 'Рамз бояд ақаллан 8 аломат бошад.';
      if (loc == 'email') return 'Почтаи электронӣ нодуруст аст.';
      return 'Маълумот нодуруст аст.';
    }
    return null;
  }

  // ---------- Auth ----------

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
  ) => _send(
    'POST',
    '/api/mobile/v3/auth/register',
    body: {'email': email, 'password': password, 'full_name': fullName},
    auth: false,
  );

  Future<Map<String, dynamic>> login(String email, String password) => _send(
    'POST',
    '/api/mobile/v3/auth/login',
    body: {'email': email, 'password': password},
    auth: false,
  );

  Future<Map<String, dynamic>> google(String idToken) => _send(
    'POST',
    '/api/mobile/v3/auth/google',
    body: {'id_token': idToken},
    auth: false,
  );

  Future<void> logout() => _send('POST', '/api/mobile/v3/auth/logout');

  Future<Map<String, dynamic>> me() => _send('GET', '/api/mobile/v3/me');

  Future<Map<String, dynamic>> updateMe({String? fullName, String? role}) =>
      _send(
        'PUT',
        '/api/mobile/v3/me',
        body: {'full_name': ?fullName, 'role': ?role},
      );

  // ---------- Family ----------

  /// Parent: `{children: [...]}`. Child: `{child: {...} | null}`.
  Future<Map<String, dynamic>> snapshot() =>
      _send('GET', '/api/mobile/v2/snapshot');

  Future<Map<String, dynamic>> createPairCode({
    required String childName,
    required String gender,
    required int age,
  }) => _send(
    'POST',
    '/api/mobile/v2/pair/code',
    body: {'child_name': childName, 'gender': gender, 'age': age},
  );

  Future<Map<String, dynamic>> pair(String code) => _send(
    'POST',
    '/api/mobile/v2/pair',
    body: {'pairing_code': code},
  );

  Future<void> unlinkChild(int childId) =>
      _send('DELETE', '/api/mobile/v2/children/$childId');

  // ---------- Apps ----------

  Future<Map<String, dynamic>> syncApps(
    int childId,
    List<Map<String, dynamic>> apps,
  ) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/apps/sync',
    body: {'apps': apps},
  );

  /// [rule] keys: is_blocked (bool), daily_limit_minutes (int),
  /// schedule ({enabled, start 'HH:mm', end 'HH:mm', weekdays [1..7]}).
  Future<Map<String, dynamic>> updateRule(
    int childId,
    String packageName,
    Map<String, dynamic> rule,
  ) => _send(
    'PUT',
    '/api/mobile/v2/children/$childId/apps/${Uri.encodeComponent(packageName)}',
    body: rule,
  );

  // ---------- Location ----------

  Future<void> syncLocation(int childId, Map<String, dynamic> location) =>
      _send('POST', '/api/mobile/v2/children/$childId/location', body: location);

  // ---------- Chat ----------

  Future<List<Map<String, dynamic>>> chat(int childId, {int afterId = 0}) async {
    final data = await _send(
      'GET',
      '/api/mobile/v2/children/$childId/chat',
      query: afterId > 0 ? {'after_id': '$afterId'} : null,
    );
    return (data['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// message_type: 'text' | 'call' (call request shown to the other side).
  Future<Map<String, dynamic>> sendChat(
    int childId,
    String content, {
    String messageType = 'text',
  }) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/chat',
    body: {'content': content, 'message_type': messageType, 'duration_sec': 0},
  );

  // ---------- Updates ----------

  Future<Map<String, dynamic>> version(int currentVersionCode) => _send(
    'GET',
    '/api/mobile/version',
    query: {'current_version_code': '$currentVersionCode'},
    auth: false,
  );
}
