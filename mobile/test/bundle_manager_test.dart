import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nigoh_family_parent/core/bundle_manager.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads cached bundle before any network request', () async {
    SharedPreferences.setMockInitialValues({
      DynamicConfigNotifier.storageKey: jsonEncode({
        'bundle_version': 7,
        'ui_overrides': {
          'theme': {'primaryColor': '#123456'},
          'strings': {'home_title': 'Оилаи ман'},
        },
        'cached_rules_template': {'defaultDailyLimitMinutes': 45},
      }),
    });

    final manager = DynamicConfigNotifier();
    await manager.loadLocal();

    expect(manager.currentBundleVersion, 7);
    expect(manager.text('home_title'), 'Оилаи ман');
    expect(manager.defaultDailyLimitMinutes, 45);
  });

  test('verifies and hot-applies a remote patch, then persists it', () async {
    final payload = <String, dynamic>{
      'ui_overrides': {
        'theme': {'primaryColor': '#123456'},
        'strings': {'update_banner': 'Навсозӣ омода аст'},
      },
      'cached_rules_template': {'defaultDailyLimitMinutes': 120},
    };
    final checksum = DynamicConfigNotifier.checksumFor(payload);
    var notifications = 0;
    final manager = DynamicConfigNotifier(
      fetcher: (uri, headers) async {
        expect(uri.queryParameters['client_bundle_version'], '0');
        return BundleHttpResponse(
          200,
          jsonEncode({
            'has_update': true,
            'bundle_version': 2,
            'patches': [
              {
                'bundle_version': 2,
                'min_native_code': 24,
                'patch_type': 'config',
                'payload': payload,
                'checksum': checksum,
              },
            ],
          }),
        );
      },
    )..addListener(() => notifications++);

    final result = await manager.sync(
      endpointBaseUrl: 'https://example.test',
      nativeVersionCode: 24,
    );

    expect(result.applied, isTrue);
    expect(manager.currentBundleVersion, 2);
    expect(manager.primaryColor.toARGB32(), 0xff123456);
    expect(manager.text('update_banner'), 'Навсозӣ омода аст');
    expect(manager.defaultDailyLimitMinutes, 120);
    expect(notifications, greaterThan(0));

    final restored = DynamicConfigNotifier();
    await restored.loadLocal();
    expect(restored.currentBundleVersion, 2);
    expect(restored.text('update_banner'), 'Навсозӣ омода аст');
  });

  test('treats HTTP 304 as a no-op', () async {
    final manager = DynamicConfigNotifier(
      fetcher: (uri, headers) async => const BundleHttpResponse(304, ''),
    );

    final result = await manager.sync(
      endpointBaseUrl: 'https://example.test',
      nativeVersionCode: 24,
    );

    expect(result.applied, isFalse);
    expect(result.notModified, isTrue);
    expect(result.error, isNull);
  });
}
