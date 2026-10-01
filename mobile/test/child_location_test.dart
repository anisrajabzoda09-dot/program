import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/features/child/child_sync.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Position pos(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.utc(2026, 10, 1, 8),
  accuracy: 30,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// Geolocator platform with no stream events (like a phone indoors).
class FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Position? lastKnown;
  Future<Position> Function()? current;
  final currentSettings = <LocationSettings?>[];
  int streamListens = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    currentSettings.add(locationSettings);
    final next = current;
    if (next == null) {
      return Future.error(TimeoutException('no fix'));
    }
    return next();
  }

  /// Never emits — the bug case: indoors the stream stays silent.
  final silent = StreamController<Position>.broadcast();

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamListens++;
    return silent.stream;
  }
}

Map<String, dynamic> child() => {
  'id': 5,
  'name': 'Алӣ',
  'pairing_code': '482913',
  'is_paired': true,
  'apps': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tj.nigoh/device_control');
  late GeolocatorPlatform original;
  late FakeGeolocator geo;
  late List<Map<String, dynamic>> posted;
  late int? battery;
  late int locationStatus;
  late DateTime clock;

  setUp(() {
    original = GeolocatorPlatform.instance;
    geo = FakeGeolocator();
    GeolocatorPlatform.instance = geo;
    posted = [];
    battery = 64;
    locationStatus = 200;
    clock = DateTime(2026, 10, 1, 12);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getBatteryLevel':
              return battery;
            case 'getInstalledApps':
              return [
                {'packageName': 'com.a', 'appName': 'A'},
              ];
            case 'getProtectionStatus':
              return {'location': true};
          }
          return null;
        });
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  ChildSync makeSync() => ChildSync(
    api: NigohApi(
      client: MockClient((req) async {
        if (req.url.path == '/api/mobile/v2/snapshot') {
          return json({'child': child()});
        }
        if (req.url.path == '/api/mobile/v2/children/5/location') {
          if (locationStatus != 200) {
            return json({'detail': 'Сервер банд аст'}, locationStatus);
          }
          posted.add(jsonDecode(req.body) as Map<String, dynamic>);
          return json({'status': 'success'});
        }
        return json({'status': 'success'});
      }),
      baseUrl: 'http://t',
    ),
    listenPackageEvents: false,
    clock: () => clock,
  );

  Future<void> settle(ChildSync sync) async {
    await sync.tick();
    while (sync.pendingFix != null) {
      await sync.pendingFix;
    }
  }

  test('no stream events: a one-shot fix is posted within one tick', () async {
    geo.current = () async => pos(38.5598, 68.787);
    final sync = makeSync();
    await settle(sync);
    expect(geo.streamListens, 1, reason: 'the stream is still started');
    expect(posted, hasLength(1));
    expect(posted.single['latitude'], 38.5598);
    expect(posted.single['longitude'], 68.787);
    expect(posted.single['battery_level'], 64);
    expect(posted.single['is_online'], isTrue);
    expect(sync.lastLocationSync, isNotNull);
    expect(sync.lastError, isNull);
    final settings = geo.currentSettings.single!;
    expect(settings.accuracy, LocationAccuracy.medium);
    expect(settings.timeLimit, ChildSync.locationFixTimeLimit);
    sync.dispose();
  });

  test('last known position is posted first, then a fresh fix', () async {
    geo.lastKnown = pos(38.1, 68.1);
    geo.current = () async => pos(38.2, 68.2);
    battery = null; // battery is optional
    final sync = makeSync();
    await settle(sync);
    expect(posted.map((p) => p['latitude']), [38.1, 38.2]);
    expect(posted.first.containsKey('battery_level'), isFalse);
    expect(sync.lastPosition?.latitude, 38.2);
    sync.dispose();
  });

  test('no repeat inside 60 s, a new fix after 60 s', () async {
    geo.current = () async => pos(38.5, 68.7);
    final sync = makeSync();
    await settle(sync);
    expect(geo.currentSettings, hasLength(1));
    clock = clock.add(const Duration(seconds: 30));
    await settle(sync);
    expect(geo.currentSettings, hasLength(1));
    clock = clock.add(const Duration(seconds: 31));
    await settle(sync);
    expect(geo.currentSettings, hasLength(2));
    expect(posted, hasLength(2));
    sync.dispose();
  });

  test('one-shot fixes never overlap', () async {
    final pending = Completer<Position>();
    geo.current = () => pending.future;
    final sync = makeSync();
    await sync.tick();
    await sync.tick();
    await sync.tick();
    expect(geo.currentSettings, hasLength(1));
    pending.complete(pos(38.5, 68.7));
    await sync.pendingFix;
    expect(posted, hasLength(1));
    sync.dispose();
  });

  test('GPS off is reported clearly', () async {
    geo.serviceEnabled = false;
    final sync = makeSync();
    await settle(sync);
    expect(sync.lastError, contains('GPS хомӯш аст'));
    expect(geo.currentSettings, isEmpty);
    sync.dispose();
  });

  test('missing permission is reported clearly', () async {
    geo.permission = LocationPermission.denied;
    final sync = makeSync();
    await settle(sync);
    expect(sync.lastError, contains('Иҷозати ҷойгиршавӣ'));
    expect(posted, isEmpty);
    sync.dispose();
  });

  test('no fix is reported and retried on the next tick', () async {
    final sync = makeSync();
    await settle(sync); // current == null → TimeoutException
    expect(sync.lastError, contains('муайян нашуд'));
    geo.current = () async => pos(38.5, 68.7);
    await settle(sync);
    expect(posted, hasLength(1));
    expect(sync.lastError, isNull);
    sync.dispose();
  });

  test('server error is visible and retried', () async {
    geo.current = () async => pos(38.5, 68.7);
    locationStatus = 503;
    final sync = makeSync();
    await settle(sync);
    expect(sync.lastError, contains('ба сервер фиристода нашуд'));
    expect(sync.lastError, contains('Сервер банд аст'));
    locationStatus = 200;
    await settle(sync);
    expect(posted, hasLength(1));
    expect(sync.lastError, isNull);
    sync.dispose();
  });
}
