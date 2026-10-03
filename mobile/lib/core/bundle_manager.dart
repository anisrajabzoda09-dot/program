// Файл: зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдаст.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Шакли callback-и истифодашавандаро барои зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдаст муайян мекунад.
typedef BundleFetcher = Future<BundleHttpResponse> Function(
  Uri uri,
  Map<String, String> headers,
);

/// Додаҳо ва рафтори марбут ба зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро ифода мекунад.
class BundleHttpResponse {
  const BundleHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

/// Додаҳо ва рафтори марбут ба зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро ифода мекунад.
class BundleSyncResult {
  const BundleSyncResult({
    required this.applied,
    required this.notModified,
    this.requiresFullReinstall = false,
    this.error,
  });

  final bool applied;
  final bool notModified;
  final bool requiresFullReinstall;
  final String? error;
}

/// Мантиқ ва ҳолати зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро идора мекунад.
class DynamicConfigNotifier extends ChangeNotifier {
  DynamicConfigNotifier({this.fetcher});

  static const storageKey = 'nigoh_dynamic_bundle_v1';

  static const Map<String, dynamic> baseBundle = {
    'bundle_version': 0,
    'ui_overrides': {
      'theme': {
        'primaryColor': '#0095F6',
        'secondaryColor': '#070D18',
        'backgroundColor': '#FFFFFF',
        'surfaceColor': '#FFFFFF',
        'accentColor': '#00A98F',
      },
      'strings': {
        'app_name': 'NIGOH Family',
        'home_title': 'NIGOH Family',
        'parent_home_title': 'NIGOH Apps',
        'update_banner': 'Муҳофизати оила фаъол аст',
      },
      'visibility': {'demoLogin': true, 'homeworkMode': true},
    },
    'cached_rules_template': {
      'defaultDailyLimitMinutes': 90,
      'homeworkStart': '16:00',
      'homeworkEnd': '18:00',
      'homeworkWeekdays': [1, 2, 3, 4, 5],
    },
  };

  final BundleFetcher? fetcher;
  SharedPreferences? _prefs;
  Map<String, dynamic> _active = _deepCopy(baseBundle);
  bool _loaded = false;

  /// Қимати ҳисобшудаи currentBundleVersion-ро аз ҳолати ҷорӣ бармегардонад.
  int get currentBundleVersion =>
      (_active['bundle_version'] as num?)?.toInt() ?? 0;

  /// Қимати ҳисобшудаи uiOverrides-ро аз ҳолати ҷорӣ бармегардонад.
  Map<String, dynamic> get uiOverrides => _map(_active['ui_overrides']);

  /// Қимати ҳисобшудаи cachedRulesTemplate-ро аз ҳолати ҷорӣ бармегардонад.
  Map<String, dynamic> get cachedRulesTemplate =>
      _map(_active['cached_rules_template']);

  /// text мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад.
  String text(String key, {String fallback = ''}) {
    final strings = _map(uiOverrides['strings']);
    final value = strings[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  /// visible мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад.
  bool visible(String key, {bool fallback = true}) {
    final visibility = _map(uiOverrides['visibility']);
    final value = visibility[key];
    return value is bool ? value : fallback;
  }

  /// ruleInt мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад.
  int ruleInt(String key, {required int fallback}) {
    final value = cachedRulesTemplate[key];
    return value is num ? value.toInt() : fallback;
  }

  /// ruleString мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад.
  String ruleString(String key, {required String fallback}) {
    final value = cachedRulesTemplate[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  /// Қимати ҳисобшудаи defaultDailyLimitMinutes-ро аз ҳолати ҷорӣ бармегардонад.
  int get defaultDailyLimitMinutes =>
      ruleInt('defaultDailyLimitMinutes', fallback: 90);

  /// Қимати ҳисобшудаи primaryColor-ро аз ҳолати ҷорӣ бармегардонад.
  Color get primaryColor => color('primaryColor', const Color(0xFF0095F6));
  /// Қимати ҳисобшудаи secondaryColor-ро аз ҳолати ҷорӣ бармегардонад.
  Color get secondaryColor => color('secondaryColor', const Color(0xFF070D18));
  /// Қимати ҳисобшудаи backgroundColor-ро аз ҳолати ҷорӣ бармегардонад.
  Color get backgroundColor => color('backgroundColor', Colors.white);
  /// Қимати ҳисобшудаи surfaceColor-ро аз ҳолати ҷорӣ бармегардонад.
  Color get surfaceColor => color('surfaceColor', Colors.white);
  /// Қимати ҳисобшудаи accentColor-ро аз ҳолати ҷорӣ бармегардонад.
  Color get accentColor => color('accentColor', const Color(0xFF00A98F));

  /// color қисми мувофиқи интерфейсро месозад.
  Color color(String key, Color fallback) {
    final theme = _map(uiOverrides['theme']);
    final raw = theme[key];
    if (raw is! String) return fallback;
    final hex = raw.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null || (hex.length != 6 && hex.length != 8)) return fallback;
    return Color(hex.length == 6 ? 0xFF000000 | value : value);
  }

  /// loadLocal додаҳоро мехонад ва ҳолати экранро нав мекунад.
  Future<void> loadLocal() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final candidate = _merge(_deepCopy(baseBundle), decoded);
          _validateState(candidate);
          _active = candidate;
        }
      } catch (_) {
        // Хатои ин қадам нодида гирифта мешавад, то ҷараёни асосӣ қатъ нашавад.
        _active = _deepCopy(baseBundle);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// sync додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад.
  Future<BundleSyncResult> sync({
    required String endpointBaseUrl,
    required int nativeVersionCode,
    List<String> fallbackBaseUrls = const [],
  }) async {
    await loadLocal();
    final bases = <String>{endpointBaseUrl, ...fallbackBaseUrls};
    Object? lastError;
    for (final base in bases) {
      try {
        final uri = Uri.parse(base).replace(
          path: '/api/mobile/sync-bundle',
          queryParameters: {
            'client_bundle_version': '$currentBundleVersion',
            'native_version_code': '$nativeVersionCode',
          },
        );
        final response = await (fetcher ?? _fetch)(uri, {
          'Accept': 'application/json',
          'X-Client-Bundle-Version': '$currentBundleVersion',
          'X-Native-Version-Code': '$nativeVersionCode',
        });
        if (response.statusCode == 304) {
          return const BundleSyncResult(applied: false, notModified: true);
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final body = jsonDecode(response.body);
        if (body is! Map) {
          throw const FormatException('Invalid bundle response');
        }
        if (body['has_update'] != true) {
          return const BundleSyncResult(applied: false, notModified: true);
        }
        if (body['requires_full_reinstall'] == true) {
          return const BundleSyncResult(
            applied: false,
            notModified: false,
            requiresFullReinstall: true,
          );
        }
        final rawPatches = body['patches'];
        final patches = rawPatches is List ? rawPatches : <dynamic>[body];
        var candidate = _deepCopy(_active);
        for (final rawPatch in patches) {
          if (rawPatch is! Map) {
            throw const FormatException('Invalid patch item');
          }
          final patch = Map<String, dynamic>.from(rawPatch);
          final payload = patch['payload'];
          if (payload is! Map) {
            throw const FormatException('Patch payload is not an object');
          }
          final payloadMap = Map<String, dynamic>.from(payload);
          final expected = patch['checksum']?.toString() ?? '';
          if (expected.isEmpty || expected != checksumFor(payloadMap)) {
            throw const FormatException('Patch checksum mismatch');
          }
          final minNative = (patch['min_native_code'] as num?)?.toInt() ?? 0;
          final patchType = patch['patch_type']?.toString() ?? 'config';
          if (minNative > nativeVersionCode || patchType == 'full_bundle') {
            return const BundleSyncResult(
              applied: false,
              notModified: false,
              requiresFullReinstall: true,
            );
          }
          candidate = _merge(candidate, payloadMap);
          candidate['bundle_version'] =
              (patch['bundle_version'] as num?)?.toInt() ??
              (body['bundle_version'] as num?)?.toInt() ??
              currentBundleVersion;
        }
        _validateState(candidate);
        _active = candidate;
        await _persist();
        notifyListeners();
        return const BundleSyncResult(applied: true, notModified: false);
      } catch (error) {
        lastError = error;
      }
    }
    return BundleSyncResult(
      applied: false,
      notModified: false,
      error: lastError?.toString(),
    );
  }

  /// checksumFor дурустӣ ва шартҳои зарурии додаҳоро месанҷад.
  static String checksumFor(Map<String, dynamic> payload) =>
      sha256.convert(utf8.encode(_canonicalJson(payload))).toString();

  /// persist тағйиротро барои истифодаи баъдӣ нигоҳ медорад.
  Future<void> _persist() async {
    await (_prefs ??= await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode(_active),
    );
  }

  /// fetch додаҳоро мехонад ва ҳолати экранро нав мекунад.
  static Future<BundleHttpResponse> _fetch(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return BundleHttpResponse(response.statusCode, body);
    } finally {
      client.close(force: true);
    }
  }

  /// map мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад.
  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  /// deepCopy мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад.
  static Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  /// merge мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад.
  static Map<String, dynamic> _merge(
    Map<String, dynamic> base,
    Map<dynamic, dynamic> patch,
  ) {
    final result = _deepCopy(base);
    patch.forEach((key, value) {
      final name = key.toString();
      if (value is Map && result[name] is Map) {
        result[name] = _merge(_map(result[name]), value);
      } else {
        result[name] = value;
      }
    });
    return result;
  }

  /// validateState дурустӣ ва шартҳои зарурии додаҳоро месанҷад.
  static void _validateState(Map<String, dynamic> value) {
    if (value['bundle_version'] is! num) {
      throw const FormatException('Invalid bundle version');
    }
    if (value['ui_overrides'] is! Map ||
        value['cached_rules_template'] is! Map) {
      throw const FormatException('Invalid bundle structure');
    }
  }

  /// canonicalJson иҷро шудани шарти вобастаро муайян мекунад.
  static String _canonicalJson(dynamic value) {
    /// normalize додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад.
    dynamic normalize(dynamic item) {
      if (item is Map) {
        final keys = item.keys.map((key) => key.toString()).toList()..sort();
        return <String, dynamic>{
          for (final key in keys) key: normalize(item[key]),
        };
      }
      if (item is List) return item.map(normalize).toList();
      return item;
    }

    return jsonEncode(normalize(value));
  }
}

final dynamicConfig = DynamicConfigNotifier();
