// Файл: муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

import '../l10n/l10n.dart';

/// Қимати nigohApiBaseUrl-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
const nigohApiBaseUrl = String.fromEnvironment(
  'NIGOH_API_BASE_URL',
  defaultValue: 'https://nigohfamily.qobus.tj',
);

/// ApiException додаҳо ва рафтори API ва session-ро ифода мекунад.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  /// Қимати ҳисобшудаи unauthorized-ро аз ҳолати ҷорӣ бармегардонад.
  bool get unauthorized => statusCode == 401;

  /// Намоиши матнии ApiException-ро барои log бармегардонад.
  @override
  String toString() => message;
}

/// AppleSignInConfig додаҳо ва рафтори API ва session-ро ифода мекунад.
class AppleSignInConfig {
  const AppleSignInConfig({
    required this.enabled,
    this.clientId,
    this.redirectUri,
  });

  /// AppleSignInConfig-ро аз JSON-и сервер месозад.
  factory AppleSignInConfig.fromJson(Map<String, dynamic> json) {
    final clientId = json['client_id']?.toString() ?? '';
    final redirectUri = json['redirect_uri']?.toString() ?? '';
    return AppleSignInConfig(
      enabled:
          json['enabled'] == true &&
          clientId.isNotEmpty &&
          redirectUri.isNotEmpty,
      clientId: clientId.isEmpty ? null : clientId,
      redirectUri: redirectUri.isEmpty ? null : redirectUri,
    );
  }

  /// Қимати enabled-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
  final bool enabled;

  /// Қимати clientId-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
  final String? clientId;

  /// Қимати redirectUri-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
  final String? redirectUri;
}

/// GitHubSignInConfig додаҳо ва рафтори API ва session-ро ифода мекунад.
class GitHubSignInConfig {
  const GitHubSignInConfig({
    required this.enabled,
    this.startUrl,
    this.callbackScheme,
  });

  /// GitHubSignInConfig-ро аз JSON-и сервер месозад.
  factory GitHubSignInConfig.fromJson(Map<String, dynamic> json) {
    final startUrl = json['start_url']?.toString() ?? '';
    final callbackScheme = json['callback_scheme']?.toString() ?? '';
    return GitHubSignInConfig(
      enabled:
          json['enabled'] == true &&
          startUrl.isNotEmpty &&
          callbackScheme.isNotEmpty,
      startUrl: startUrl.isEmpty ? null : startUrl,
      callbackScheme: callbackScheme.isEmpty ? null : callbackScheme,
    );
  }

  /// Қимати enabled-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
  final bool enabled;

  /// Қимати startUrl-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
  final String? startUrl;

  /// Қимати callbackScheme-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
  final String? callbackScheme;
}

/// NigohApi додаҳо ва рафтори API ва session-ро ифода мекунад.
class NigohApi {
  NigohApi({http.Client? client, this.baseUrl = nigohApiBaseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  /// Қимати token-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
  String? token;

  /// Қимати role-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад.
  String? role;

  /// Function мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 15);

  /// send дархостро ба API мефиристад ва натиҷаро коркард мекунад.
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
        // Додаҳо ба шакли бехатар табдил ва санҷида мешаванд.
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

  /// detail мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
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

  // Қадами дохилии register барои API ва session.

  /// register дархостро ба API мефиристад ва натиҷаро коркард мекунад.
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

  /// login дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<Map<String, dynamic>> login(String email, String password) => _send(
    'POST',
    '/api/mobile/v3/auth/login',
    body: {'email': email, 'password': password},
    auth: false,
  );

  /// google экран, dialog ё танзимоти мувофиқро мекушояд.
  Future<Map<String, dynamic>> google(String idToken) => _send(
    'POST',
    '/api/mobile/v3/auth/google',
    body: {'id_token': idToken},
    auth: false,
  );

  /// appleConfig мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<AppleSignInConfig> appleConfig() async => AppleSignInConfig.fromJson(
    await _send('GET', '/api/mobile/v3/auth/apple/config', auth: false),
  );

  /// signInWithApple мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<Map<String, dynamic>> signInWithApple({
    required String identityToken,
    required String nonce,
    String? fullName,
  }) => _send(
    'POST',
    '/api/mobile/v3/auth/apple',
    body: {
      'identity_token': identityToken,
      'nonce': nonce,
      'full_name': fullName,
    },
    auth: false,
  );

  /// Кадом навъҳои ҳимояи дуқабата дар сервер фаъоланд (Authenticator, рамз ба почта).
  Future<({bool totp, bool email})> otpConfig() async {
    final j = await _send('GET', '/api/mobile/v3/auth/otp/config', auth: false);
    return (totp: j['totp'] == true, email: j['email'] == true);
  }

  /// Қадами дуюми воридшавӣ: чипта аз login ва рамзи 6-рақама ё рамзи эҳтиётӣ.
  Future<Map<String, dynamic>> loginOtp(String ticket, String code) => _send(
    'POST',
    '/api/mobile/v3/auth/login/otp',
    body: {'ticket': ticket, 'code': code},
    auth: false,
  );

  /// Рамзи воридшавиро ба почта мефиристад.
  Future<Map<String, dynamic>> requestEmailCode(String email) => _send(
    'POST',
    '/api/mobile/v3/auth/email-code',
    body: {'email': email},
    auth: false,
  );

  /// Рамзи почтаро месанҷад: token ё otp_required бармегардонад.
  Future<Map<String, dynamic>> verifyEmailCode(String email, String code) =>
      _send(
        'POST',
        '/api/mobile/v3/auth/email-code/verify',
        body: {'email': email, 'code': code},
        auth: false,
      );

  /// Ҳолати Authenticator-и ҳисоби ҷорӣ.
  Future<Map<String, dynamic>> totpStatus() =>
      _send('GET', '/api/mobile/v3/me/totp');

  /// Калиди навро месозад: secret, uri ва QR.
  Future<Map<String, dynamic>> totpSetup() =>
      _send('POST', '/api/mobile/v3/me/totp/setup');

  /// Аввалин рамзро месанҷад ва рамзҳои эҳтиётиро бармегардонад.
  Future<Map<String, dynamic>> totpConfirm(String code) =>
      _send('POST', '/api/mobile/v3/me/totp/confirm', body: {'code': code});

  /// Authenticator-ро бо рамз хомӯш мекунад.
  Future<Map<String, dynamic>> totpDisable(String code) =>
      _send('POST', '/api/mobile/v3/me/totp/disable', body: {'code': code});

  /// Рамзҳои эҳтиётии нав.
  Future<Map<String, dynamic>> totpRecovery(String code) =>
      _send('POST', '/api/mobile/v3/me/totp/recovery', body: {'code': code});

  /// githubConfig мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<GitHubSignInConfig> githubConfig() async =>
      GitHubSignInConfig.fromJson(
        await _send('GET', '/api/mobile/v3/auth/github/config', auth: false),
      );

  /// signInWithGitHub мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<Map<String, dynamic>> signInWithGitHub({
    required String ticket,
    required String nonce,
  }) => _send(
    'POST',
    '/api/mobile/v3/auth/github',
    body: {'ticket': ticket, 'nonce': nonce},
    auth: false,
  );

  /// logout дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> logout() => _send('POST', '/api/mobile/v3/auth/logout');

  /// me мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<Map<String, dynamic>> me() => _send('GET', '/api/mobile/v3/me');

  /// updateMe ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<Map<String, dynamic>> updateMe({String? fullName, String? role}) =>
      _send(
        'PUT',
        '/api/mobile/v3/me',
        body: {'full_name': ?fullName, 'role': ?role},
      );

  /// uploadAvatar додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад.
  Future<String?> uploadAvatar(List<int> imageBytes) async => (await _send(
    'POST',
    '/api/mobile/v3/me/avatar',
    body: {'image_base64': base64Encode(imageBytes)},
  ))['avatar']?.toString();

  /// deleteAvatar маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
  Future<void> deleteAvatar() => _send('DELETE', '/api/mobile/v3/me/avatar');

  /// fileUrl мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  String? fileUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl$path';
  }

  // Қадами дохилии snapshot барои API ва session.

  /// snapshot мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<Map<String, dynamic>> snapshot() =>
      _send('GET', '/api/mobile/v2/snapshot');

  /// createPairCode мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<Map<String, dynamic>> createPairCode({
    required String childName,
    required String gender,
    required int age,
  }) => _send(
    'POST',
    '/api/mobile/v2/pair/code',
    body: {'child_name': childName, 'gender': gender, 'age': age},
  );

  /// pair дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<Map<String, dynamic>> pair(String code) =>
      _send('POST', '/api/mobile/v2/pair', body: {'pairing_code': code});

  /// unlinkChild маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
  Future<void> unlinkChild(int childId) =>
      _send('DELETE', '/api/mobile/v2/children/$childId');

  // Қадами дохилии syncApps барои API ва session.

  /// syncApps додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад.
  Future<Map<String, dynamic>> syncApps(
    int childId,
    List<Map<String, dynamic>> apps,
  ) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/apps/sync',
    body: {'apps': apps},
  );

  /// updateRule ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<Map<String, dynamic>> updateRule(
    int childId,
    String packageName,
    Map<String, dynamic> rule,
  ) => _send(
    'PUT',
    '/api/mobile/v2/children/$childId/apps/${Uri.encodeComponent(packageName)}',
    body: rule,
  );

  // Қадами дохилии syncLocation барои API ва session.

  /// syncLocation додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад.
  Future<void> syncLocation(int childId, Map<String, dynamic> location) =>
      _send(
        'POST',
        '/api/mobile/v2/children/$childId/location',
        body: location,
      );

  // Қадами дохилии chat барои API ва session.

  /// chat мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
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

  /// sendChat дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<Map<String, dynamic>> sendChat(
    int childId,
    String content, {
    String messageType = 'text',
  }) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/chat',
    body: {'content': content, 'message_type': messageType, 'duration_sec': 0},
  );

  /// markChatRead дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> markChatRead(int childId) =>
      _send('POST', '/api/mobile/v2/children/$childId/chat/read');

  // Қадами дохилии locationHistory барои API ва session.

  /// locationHistory мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
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

  /// usageHistory мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
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

  // Қадами дохилии requestTime барои API ва session.

  /// requestTime иҷозат ё маълумоти лозимро дархост мекунад.
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

  /// timeRequests мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
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

  /// decideTimeRequest дархостро ба API мефиристад ва натиҷаро коркард мекунад.
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

  /// giveBonus дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> giveBonus(int childId, String packageName, int minutes) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/apps/${Uri.encodeComponent(packageName)}/bonus',
    body: {'minutes': minutes},
  );

  // Қадами дохилии send барои API ва session.

  /// setBedtime ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> setBedtime(int childId, Map<String, dynamic> bedtime) => _send(
    'PUT',
    '/api/mobile/v2/children/$childId/settings',
    body: {'bedtime': bedtime},
  );

  /// safePlaces мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<List<Map<String, dynamic>>> safePlaces(int childId) async => _list(
    (await _send('GET', '/api/mobile/v2/children/$childId/places'))['places'],
  );

  /// addSafePlace мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
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

  /// Ном, радиус ё қоидаҳои ҷойро иваз мекунад.
  Future<Map<String, dynamic>> updateSafePlace(
    int childId,
    int placeId, {
    String? name,
    int? radiusMeters,
    Map<String, PlaceAppRule>? rules,
    bool? notify,
  }) => _send(
    'PUT',
    '/api/mobile/v2/children/$childId/places/$placeId',
    body: {
      'name': ?name,
      'radius_meters': ?radiusMeters,
      if (rules != null || notify != null)
        'rules': {
          'apps': {
            for (final e in (rules ?? const <String, PlaceAppRule>{}).entries)
              e.key: e.value.toJson(),
          },
          'notify': notify ?? false,
        },
    },
  );

  /// deleteSafePlace маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
  Future<void> deleteSafePlace(int childId, int placeId) =>
      _send('DELETE', '/api/mobile/v2/children/$childId/places/$placeId');

  /// list мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  static List<Map<String, dynamic>> _list(Object? raw) =>
      (raw as List? ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  /// setStudyMode ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> setStudyMode(int childId, Map<String, dynamic> study) => _send(
    'PUT',
    '/api/mobile/v2/children/$childId/settings',
    body: {'study': study},
  );

  /// Сатҳи филтри сайтҳо ва рӯйхати сайтҳои манъшударо барои фарзанд нигоҳ медорад.
  Future<Map<String, dynamic>> setWebFilter(
    int childId,
    Map<String, dynamic> webFilter,
  ) => _send(
    'PUT',
    '/api/mobile/v2/children/$childId/settings',
    body: {'web_filter': webFilter},
  );

  /// Телефони фарзанд хабар медиҳад, ки филтр кор мекунад ё не.
  Future<void> reportWebFilterState(int childId, String state) => _send(
    'POST',
    '/api/mobile/v2/children/$childId/web-filter/state',
    body: {'state': state},
  );

  // Огоҳиномаи воридшударо дар NigohApi ба амали мувофиқ равона мекунад.

  /// events мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<Map<String, dynamic>> events({int afterId = 0, int wait = 0}) => _send(
    'GET',
    '/api/mobile/v3/events',
    query: {'after_id': '$afterId', 'wait': '$wait'},
    timeout: Duration(seconds: wait + 15),
  );

  // Қадами дохилии callConfig барои API ва session.

  /// callConfig мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<List<Map<String, dynamic>>> callConfig() async =>
      _list((await _send('GET', '/api/mobile/v3/calls/config'))['ice_servers']);

  /// startCall раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  Future<Map<String, dynamic>> startCall(int childId) async =>
      Map<String, dynamic>.from(
        (await _send(
              'POST',
              '/api/mobile/v3/calls',
              body: {'child_id': childId},
            ))['call']
            as Map,
      );

  /// callStatus мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<Map<String, dynamic>> callStatus(int callId) async =>
      Map<String, dynamic>.from(
        (await _send('GET', '/api/mobile/v3/calls/$callId'))['call'] as Map,
      );

  /// acceptCall мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<void> acceptCall(int callId) =>
      _send('POST', '/api/mobile/v3/calls/$callId/accept');

  /// declineCall раванди фаъолро қатъ карда, захираҳои онро озод мекунад.
  Future<void> declineCall(int callId) =>
      _send('POST', '/api/mobile/v3/calls/$callId/decline');

  /// endCall раванди фаъолро қатъ карда, захираҳои онро озод мекунад.
  Future<void> endCall(int callId) =>
      _send('POST', '/api/mobile/v3/calls/$callId/end');

  /// sendSignal дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> sendSignal(int callId, String kind, String payload) => _send(
    'POST',
    '/api/mobile/v3/calls/$callId/signal',
    body: {'kind': kind, 'payload': payload},
  );

  /// callSignals мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
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

  // Қадами дохилии send барои API ва session.

  /// version мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад.
  Future<Map<String, dynamic>> version(int currentVersionCode) => _send(
    'GET',
    '/api/mobile/version',
    query: {'current_version_code': '$currentVersionCode'},
    auth: false,
  );
}
