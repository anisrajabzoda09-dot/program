import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const nigohApiBaseUrl = String.fromEnvironment(
  'NIGOH_API_BASE_URL',
  defaultValue: 'https://nigohfamily.qobus.tj',
);

/// FastAPI data plane used for pairing, apps, location and chat.
/// Firebase Authentication is only used to obtain an ID token; no RTDB
/// permission is required for these operations.
class NigohApi {
  NigohApi._(this.user, this.role);

  final User user;
  final String role;

  static Future<NigohApi?> current(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return NigohApi._(user, role);
  }

  Future<String> _token({bool forceRefresh = false}) async {
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) throw const NigohApiException('Сессия ба охир расид');
    return token;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool retry = true,
  }) async {
    final token = await _token();
    final uri = Uri.parse('$nigohApiBaseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'X-NIGOH-Role': role,
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send().timeout(const Duration(seconds: 12));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && retry) {
      await _token(forceRefresh: true);
      return _request(method, path, body: body, query: query, retry: false);
    }
    Map<String, dynamic> decoded = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      final raw = jsonDecode(response.body);
      if (raw is Map) decoded = Map<String, dynamic>.from(raw);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NigohApiException(
        decoded['detail']?.toString() ?? 'Хатогӣ дар сервер (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> snapshot() => _request('GET', '/api/mobile/v2/snapshot');

  Future<Map<String, dynamic>> createPairCode({
    required String childName,
    required String gender,
    required int age,
  }) => _request(
    'POST',
    '/api/mobile/v2/pair/code',
    body: {'child_name': childName, 'gender': gender, 'age': age},
  );

  Future<Map<String, dynamic>> pair(String code) => _request(
    'POST',
    '/api/mobile/v2/pair',
    body: {'pairing_code': code},
  );

  Future<Map<String, dynamic>> linkExisting(String parentFirebaseUid) => _request(
    'POST',
    '/api/mobile/v2/link-existing',
    body: {'parent_firebase_uid': parentFirebaseUid},
  );

  Future<Map<String, dynamic>> syncApps(
    int childId,
    List<Map<String, dynamic>> apps,
  ) => _request(
    'POST',
    '/api/mobile/v2/children/$childId/apps/sync',
    body: {'apps': apps},
  );

  Future<Map<String, dynamic>> updateRule(
    int childId,
    String packageName,
    Map<String, dynamic> rule,
  ) => _request(
    'PUT',
    '/api/mobile/v2/children/$childId/apps/${Uri.encodeComponent(packageName)}',
    body: rule,
  );

  Future<Map<String, dynamic>> syncLocation(
    int childId,
    Map<String, dynamic> location,
  ) => _request(
    'POST',
    '/api/mobile/v2/children/$childId/location',
    body: location,
  );

  Future<List<Map<String, dynamic>>> chat(int childId) async {
    final data = await _request('GET', '/api/mobile/v2/children/$childId/chat');
    return (data['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> sendChat(
    int childId,
    String content, {
    String messageType = 'text',
    int durationSec = 0,
  }) => _request(
    'POST',
    '/api/mobile/v2/children/$childId/chat',
    body: {
      'content': content,
      'message_type': messageType,
      'duration_sec': durationSec,
    },
  );
}

class NigohApiException implements Exception {
  const NigohApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
