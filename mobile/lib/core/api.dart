import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';

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
    Duration timeout = _timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'X-NIGOH-Device': 'android',
        'X-NIGOH-Lang': appLanguage.value,
        if (body != null) 'Content-Type': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
        'X-NIGOH-Role': ?role,
      });
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw ApiException(tr('Сервер ҷавоб надод. Интернетро санҷед.'));
    } on SocketException {
      throw ApiException(tr('Интернет нест. Пайвастшавиро санҷед.'));
    } on http.ClientException {
      throw ApiException(tr('Пайвастшавӣ ба сервер нашуд.'));
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
          tr('Хатогӣ дар сервер ({code}). Баъдтар кӯшиш кунед.', {
            'code': response.statusCode,
          }),
      statusCode: response.statusCode,
    );
  }

  static String? _detail(Object? detail) {
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      final loc = first is Map ? (first['loc'] as List?)?.last : null;
      if (loc == 'password') return tr('Рамз бояд ақаллан 8 аломат бошад.');
      if (loc == 'email') return tr('Почтаи электронӣ нодуруст аст.');
      return tr('Маълумот нодуруст аст.');
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

  /// Profile photo (JPEG/PNG bytes, resized on the phone to ~512 px).
  Future<String?> uploadAvatar(List<int> imageBytes) async => (await _send(
    'POST',
    '/api/mobile/v3/me/avatar',
    body: {'image_base64': base64Encode(imageBytes)},
  ))['avatar']?.toString();

  Future<void> deleteAvatar() => _send('DELETE', '/api/mobile/v3/me/avatar');

  /// Absolute URL for a server path like `/static/avatars/…` (null if none).
  String? fileUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl$path';
  }

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

  Future<Map<String, dynamic>> pair(String code) =>
      _send('POST', '/api/mobile/v2/pair', body: {'pairing_code': code});

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
      _send(
        'POST',
        '/api/mobile/v2/children/$childId/location',
        body: location,
      );

  // ---------- Chat ----------

  Future<List<Map<String, dynamic>>> chat(
    int childId, {
    int afterId = 0,
  }) async {
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

  /// message_type: 'text' | 'call' (call request) | 'urgent' (SOS from the child).
  Future<Map<String, dynamic>> sendChat(
    int childId,
    String content, {
    String messageType = 'text',
  }) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/chat',
    body: {'content': content, 'message_type': messageType, 'duration_sec': 0},
  );

  Future<void> markChatRead(int childId) =>
      _send('POST', '/api/mobile/v2/children/$childId/chat/read');

  // ---------- History ----------

  Future<List<Map<String, dynamic>>> locationHistory(
    int childId, {
    int hours = 24,
  }) async {
    final data = await _send(
      'GET',
      '/api/mobile/v2/children/$childId/locations',
      query: {'hours': '$hours'},
    );
    return _list(data['points']);
  }

  /// [{date, minutes, top: [{package_name, app_name, minutes}]}], oldest first.
  Future<List<Map<String, dynamic>>> usageHistory(
    int childId, {
    int days = 7,
  }) async {
    final data = await _send(
      'GET',
      '/api/mobile/v2/children/$childId/usage',
      query: {'days': '$days'},
    );
    return _list(data['days']);
  }

  // ---------- Extra time ----------

  Future<Map<String, dynamic>> requestTime(
    int childId,
    String packageName, {
    int minutes = 15,
    String? reason,
  }) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/requests',
    body: {'package_name': packageName, 'minutes': minutes, 'reason': ?reason},
  );

  /// Requests with app_name, requested_minutes, reason, status
  /// ('pending' | 'approved' | 'denied'), created_at.
  Future<List<Map<String, dynamic>>> timeRequests(
    int childId, {
    bool pendingOnly = false,
  }) async {
    final data = await _send(
      'GET',
      '/api/mobile/v2/children/$childId/requests',
      query: {'status': pendingOnly ? 'pending' : 'all'},
    );
    return _list(data['requests']);
  }

  Future<void> decideTimeRequest(
    int childId,
    int requestId, {
    required bool approve,
    int? minutes,
  }) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/requests/$requestId/decision',
    body: {'approve': approve, 'minutes': ?minutes},
  );

  Future<void> giveBonus(int childId, String packageName, int minutes) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/apps/${Uri.encodeComponent(packageName)}/bonus',
    body: {'minutes': minutes},
  );

  // ---------- Bedtime & places ----------

  /// bedtime: {enabled, start 'HH:mm', end 'HH:mm'}
  Future<void> setBedtime(int childId, Map<String, dynamic> bedtime) => _send(
    'PUT',
    '/api/mobile/v2/children/$childId/settings',
    body: {'bedtime': bedtime},
  );

  Future<List<Map<String, dynamic>>> safePlaces(int childId) async => _list(
    (await _send('GET', '/api/mobile/v2/children/$childId/places'))['places'],
  );

  Future<Map<String, dynamic>> addSafePlace(
    int childId, {
    required String name,
    required double latitude,
    required double longitude,
    int radiusMeters = 150,
  }) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/places',
    body: {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
    },
  );

  Future<void> deleteSafePlace(int childId, int placeId) =>
      _send('DELETE', '/api/mobile/v2/children/$childId/places/$placeId');

  static List<Map<String, dynamic>> _list(Object? raw) =>
      (raw as List? ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  /// study: {enabled, start 'HH:mm', end 'HH:mm', weekdays [1..7]}
  Future<void> setStudyMode(int childId, Map<String, dynamic> study) => _send(
    'PUT',
    '/api/mobile/v2/children/$childId/settings',
    body: {'study': study},
  );

  // ---------- Notifications (long-poll) ----------

  /// Events for this phone after [afterId]: {events: [...], latest_id}.
  /// afterId 0 returns only the current position. [wait] holds the request
  /// up to that many seconds until something happens.
  Future<Map<String, dynamic>> events({int afterId = 0, int wait = 0}) => _send(
    'GET',
    '/api/mobile/v3/events',
    query: {'after_id': '$afterId', 'wait': '$wait'},
    timeout: Duration(seconds: wait + 15),
  );

  // ---------- Voice calls (WebRTC signaling) ----------

  /// [{urls: [...], username?, credential?}]
  Future<List<Map<String, dynamic>>> callConfig() async =>
      _list((await _send('GET', '/api/mobile/v3/calls/config'))['ice_servers']);

  Future<Map<String, dynamic>> startCall(int childId) async =>
      Map<String, dynamic>.from(
        (await _send(
              'POST',
              '/api/mobile/v3/calls',
              body: {'child_id': childId},
            ))['call']
            as Map,
      );

  Future<Map<String, dynamic>> callStatus(int callId) async =>
      Map<String, dynamic>.from(
        (await _send('GET', '/api/mobile/v3/calls/$callId'))['call'] as Map,
      );

  Future<void> acceptCall(int callId) =>
      _send('POST', '/api/mobile/v3/calls/$callId/accept');
  Future<void> declineCall(int callId) =>
      _send('POST', '/api/mobile/v3/calls/$callId/decline');
  Future<void> endCall(int callId) =>
      _send('POST', '/api/mobile/v3/calls/$callId/end');

  /// kind: 'offer' | 'answer' | 'ice'; payload: JSON string.
  Future<void> sendSignal(int callId, String kind, String payload) => _send(
    'POST',
    '/api/mobile/v3/calls/$callId/signal',
    body: {'kind': kind, 'payload': payload},
  );

  /// {call: {...status}, signals: [{id, from_role, kind, payload}]}
  Future<Map<String, dynamic>> callSignals(
    int callId, {
    int afterId = 0,
    int wait = 0,
  }) => _send(
    'GET',
    '/api/mobile/v3/calls/$callId/signals',
    query: {'after_id': '$afterId', 'wait': '$wait'},
    timeout: Duration(seconds: wait + 15),
  );

  // ---------- Updates ----------

  Future<Map<String, dynamic>> version(int currentVersionCode) => _send(
    'GET',
    '/api/mobile/version',
    query: {'current_version_code': '$currentVersionCode'},
    auth: false,
  );
}
