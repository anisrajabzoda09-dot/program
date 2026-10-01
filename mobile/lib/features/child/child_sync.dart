import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/child_profile.dart';
import '../../core/models.dart';

/// Background engine on the child's phone. Everything goes through the NIGOH
/// server: the child record + pairing code, the installed-app list, the
/// parent's rules (pushed to the native blocker) and the location.
///
/// Errors never disappear silently: each area keeps its latest message and
/// [lastError] exposes the most recent one for the UI.
class ChildSync extends ChangeNotifier {
  ChildSync({
    required this.api,
    MethodChannel? deviceChannel,
    EventChannel? packageEvents,
    Future<ChildProfile?> Function()? loadProfile,
    this.trackLocation = true,
    this.listenPackageEvents = true,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       device = deviceChannel ?? const MethodChannel('tj.nigoh/device_control'),
       _packageEventsChannel =
           packageEvents ?? const EventChannel('tj.nigoh/package_events'),
       _loadProfile = loadProfile ?? ChildProfile.load;

  final NigohApi api;
  final MethodChannel device;
  final EventChannel _packageEventsChannel;
  final Future<ChildProfile?> Function() _loadProfile;
  final bool trackLocation;
  final bool listenPackageEvents;
  final DateTime Function() _clock;

  /// Current time (injectable for tests).
  DateTime now() => _clock();

  static const pollInterval = Duration(seconds: 15);
  static const appsInterval = Duration(minutes: 10);
  static const locationThrottle = Duration(seconds: 60);
  static const locationHeartbeat = Duration(minutes: 5);

  /// A one-shot fix is requested when nothing was posted for this long,
  /// independent of the GPS stream (indoors the stream may stay silent).
  static const locationFixEvery = Duration(seconds: 60);
  static const locationFixTimeLimit = Duration(seconds: 20);

  /// Server usage values must stay inside the schema (0..1440) or the whole
  /// batch is rejected.
  static int clampUsage(Object? minutes) =>
      ((minutes as num?)?.toInt() ?? 0).clamp(0, 1440);

  // ---------- Status for the UI ----------

  /// True until the first attempt to find/create the child record finished.
  bool loading = true;
  int? childId;
  String? pairingCode;
  bool paired = false;
  String? parentName;
  DateTime? lastAppsSync;
  DateTime? lastLocationSync;
  DateTime? lastRulesSync;
  int appsCount = 0;
  int rulesCount = 0;

  /// The latest child record from the server (rules, bedtime, unread count).
  FamilyChild? child;

  /// Last battery level read from the phone (0..100), if known.
  int? batteryLevel;

  /// The newest GPS position this phone knows (posted or not).
  Position? get lastPosition => _lastPosition;

  /// Raw native protection status (usage, overlay, accessibility, location…).
  Map<String, dynamic> protection = const {};

  /// Whether [protection] has been read at least once.
  bool protectionKnown = false;

  /// Human-readable names of required permissions that are still missing.
  List<String> missingPermissions = const [];

  final _errors = <String, String>{}; // insertion-ordered

  /// The latest error message (Tajik), or null when everything works.
  String? get lastError => _errors.isEmpty ? null : _errors.values.last;

  // ---------- Internals ----------

  Timer? _timer;
  StreamSubscription<Position>? _positions;
  StreamSubscription<Object?>? _packageSub;
  bool _running = false;
  bool _disposed = false;
  bool _appsDirty = true;
  bool _locationStarting = false;
  Position? _lastPosition;
  bool _lastPositionSent = true;
  DateTime? _lastLocationPost;

  Future<void>? _ensureInFlight;
  Future<void>? _tickInFlight;
  Future<void>? _appsInFlight;
  Future<void>? _locationInFlight;
  Future<void>? _fixInFlight;
  bool _triedLastKnown = false;

  static const _requiredPermissions = <String, String>{
    'location': 'Ҷойгиршавӣ',
    'notifications': 'Огоҳиномаҳо',
    'usage': 'Вақти истифодаи барномаҳо',
    'overlay': 'Экрани муҳофизат',
    'accessibility': 'Назорати барномаҳо',
  };

  void _setError(String area, Object error) {
    _errors.remove(area);
    _errors[area] = error is String ? error : _text(error);
  }

  void _clearError(String area) => _errors.remove(area);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------- Lifecycle ----------

  void start() {
    if (_running || _disposed) return;
    _running = true;
    _appsDirty = true;
    unawaited(tick());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(tick()));
    if (listenPackageEvents) {
      try {
        _packageSub = _packageEventsChannel.receiveBroadcastStream().listen(
          (_) {
            _appsDirty = true;
            unawaited(syncApps());
          },
          onError: (Object e) {
            debugPrint('package_events: $e');
          },
        );
      } catch (e) {
        debugPrint('package_events: $e');
      }
    }
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _positions?.cancel();
    _positions = null;
    _triedLastKnown = false;
    _packageSub?.cancel();
    _packageSub = null;
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }

  /// «Аз нав кӯшиш»: run every step now (apps are re-sent too).
  Future<void> forceSync() async {
    _appsDirty = true;
    await tick();
    if (_tickInFlight != null) await _tickInFlight;
    if (_appsInFlight != null) await _appsInFlight;
  }

  // ---------- Child record / pairing ----------

  /// Finds this phone's child record on the server or creates it (with the
  /// profile the child entered) so a pairing code exists.
  Future<void> ensureChild() {
    return _ensureInFlight ??= _ensureChild().whenComplete(
      () => _ensureInFlight = null,
    );
  }

  Future<void> _ensureChild() async {
    try {
      final snapshot = await api.snapshot();
      final child = snapshot['child'];
      if (child is Map) {
        await _applyChild(Map<String, dynamic>.from(child));
      } else {
        await _createCode();
      }
      _clearError('child');
    } catch (e) {
      _setError('child', e);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _createCode() async {
    final profile = await _loadProfile();
    final data = await api.createPairCode(
      childName: (profile?.name.trim().isNotEmpty ?? false)
          ? profile!.name.trim()
          : 'Фарзанд',
      gender: profile?.gender ?? 'boy',
      age: profile?.age ?? 11,
    );
    childId = (data['child_id'] as num?)?.toInt() ?? childId;
    pairingCode = data['pairing_code']?.toString() ?? pairingCode;
    final nowPaired = data['paired'] == true;
    if (nowPaired && !paired) _appsDirty = true;
    paired = nowPaired;
  }

  /// A fresh pairing code (only while not paired). Throws [ApiException] so
  /// the screen can show it.
  Future<void> regenerateCode() async {
    if (paired) return;
    try {
      await _createCode();
      _clearError('child');
    } catch (e) {
      _setError('child', e);
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<void> _applyChild(Map<String, dynamic> raw) async {
    final child = FamilyChild.fromJson(raw);
    this.child = child;
    final wasPaired = paired;
    childId = child.id;
    pairingCode = child.pairingCode.isEmpty ? pairingCode : child.pairingCode;
    paired = child.paired;
    parentName = (child.parentName?.trim().isEmpty ?? true)
        ? null
        : child.parentName!.trim();
    if (paired && !wasPaired) _appsDirty = true;
    // After an unlink the phone must stop enforcing old rules.
    await pushRules(
      paired ? child.apps : const [],
      bedtime: paired ? child.bedtime : const Bedtime(),
    );
  }

  /// Sends the parent's rules to the native blocker. Bonus time, «always
  /// allowed» and an active [bedtime] are folded in by [ChildApp.toNativeRule].
  Future<void> pushRules(
    List<ChildApp> apps, {
    Bedtime bedtime = const Bedtime(),
  }) async {
    final bedtimeActive = bedtime.activeAt(now());
    try {
      await device.invokeMethod<void>('setAppControlRules', {
        'rules': apps
            .map((a) => a.toNativeRule(bedtimeActive: bedtimeActive))
            .toList(),
      });
      rulesCount = apps.length;
      lastRulesSync = DateTime.now();
      _clearError('rules');
    } on MissingPluginException {
      // Not on Android (tests / desktop) — nothing to enforce.
    } catch (e) {
      _setError('rules', 'Қоидаҳо дар телефон татбиқ нашуданд: ${_text(e)}');
    }
  }

  // ---------- Periodic step ----------

  /// One 15-second step; overlapping calls share the running one.
  Future<void> tick() {
    return _tickInFlight ??= _tick().whenComplete(() => _tickInFlight = null);
  }

  Future<void> _tick() async {
    if (childId == null) {
      await ensureChild();
    } else {
      try {
        final snapshot = await api.snapshot();
        final child = snapshot['child'];
        if (child is Map) {
          await _applyChild(Map<String, dynamic>.from(child));
        } else {
          childId = null;
          paired = false;
          this.child = null;
          await pushRules(const []);
          await ensureChild();
        }
        _clearError('child');
      } catch (e) {
        _setError('child', e);
      }
    }
    await refreshProtection();
    if (childId != null) {
      final last = lastAppsSync;
      if (_appsDirty ||
          last == null ||
          DateTime.now().difference(last) >= appsInterval) {
        unawaited(syncApps());
      }
      if (trackLocation) await startLocation();
    }
    _notify();
  }

  // ---------- Protection status ----------

  Future<void> refreshProtection() async {
    try {
      final raw = await device.invokeMapMethod<String, dynamic>(
        'getProtectionStatus',
      );
      protection = raw ?? const {};
      protectionKnown = true;
      missingPermissions = [
        for (final entry in _requiredPermissions.entries)
          if (protection[entry.key] != true) entry.value,
      ];
      _clearError('protection');
    } on MissingPluginException {
      // Not on Android.
    } catch (e) {
      _setError('protection', 'Ҳолати иҷозатҳо санҷида нашуд: ${_text(e)}');
    }
  }

  // ---------- Installed apps ----------

  Future<void> syncApps() {
    return _appsInFlight ??= _syncApps().whenComplete(
      () => _appsInFlight = null,
    );
  }

  Future<void> _syncApps() async {
    final id = childId;
    if (id == null) return;
    try {
      final apps = await buildAppsPayload();
      if (apps.isEmpty) {
        throw const ApiException('Рӯйхати барномаҳои телефон гирифта нашуд.');
      }
      await api.syncApps(id, apps);
      appsCount = apps.length;
      lastAppsSync = DateTime.now();
      _appsDirty = false;
      _clearError('apps');
    } catch (e) {
      // Stays dirty: the next 15-second tick retries.
      _appsDirty = true;
      _setError('apps', 'Барномаҳо фиристода нашуданд: ${_text(e)}');
    } finally {
      _notify();
    }
  }

  /// Installed apps + today's usage in the server's `apps/sync` format.
  Future<List<Map<String, dynamic>>> buildAppsPayload() async {
    final installed =
        await device.invokeListMethod<Object?>('getInstalledApps') ??
        const <Object?>[];
    var usageRaw = const <Object?>[];
    try {
      usageRaw =
          await device.invokeListMethod<Object?>('getUsageStats') ??
          const <Object?>[];
    } catch (e) {
      // Usage access may be missing; the app list is still useful.
      debugPrint('getUsageStats: $e');
    }
    final usage = <String, Map>{};
    for (final raw in usageRaw) {
      if (raw is Map) {
        final pkg = raw['packageName']?.toString() ?? '';
        if (pkg.isNotEmpty) usage[pkg] = raw;
      }
    }
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final raw in installed) {
      if (raw is! Map) continue;
      final pkg = raw['packageName']?.toString() ?? '';
      if (pkg.isEmpty || pkg.length > 255 || !seen.add(pkg)) continue;
      var name = (raw['appName'] ?? raw['name'])?.toString() ?? pkg;
      if (name.length > 255) name = name.substring(0, 255);
      var icon = raw['iconBase64']?.toString() ?? '';
      if (icon.length > 300000) icon = '';
      final lastUsed = (usage[pkg]?['lastUsedAt'] as num?)?.toInt() ?? 0;
      result.add({
        'package_name': pkg,
        'app_name': name,
        'icon_base64': icon,
        'is_system_app': raw['isSystemApp'] == true || raw['system'] == true,
        'usage_minutes': clampUsage(usage[pkg]?['minutes']),
        'last_used_at': lastUsed <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastUsed)
                  .toUtc()
                  .toIso8601String(),
      });
    }
    return result;
  }

  // ---------- Location ----------

  static const _gpsOffText =
      'GPS хомӯш аст — ҷойгиршавӣ фиристода намешавад. Онро дар танзимоти телефон фаъол кунед.';
  static const _noPermissionText =
      'Иҷозати ҷойгиршавӣ дода нашудааст — волидайн ҷои шуморо намебинанд.';
  static const _noFixText =
      'Ҷойгиршавӣ ҳоло муайян нашуд (сигнали GPS нест). Боз кӯшиш мекунем.';

  /// One location step (run by every tick). It never depends on the GPS
  /// stream alone — indoors the stream can stay silent for hours:
  /// 1. GPS and permission are checked; a clear error is kept otherwise;
  /// 2. the stream is (re)started and its moves are posted once a minute;
  /// 3. when nothing was posted for [locationFixEvery], a one-shot fix is
  ///    requested: the last known position first (only once, right after
  ///    start), then a medium-accuracy fix limited to 20 seconds.
  Future<void> startLocation() async {
    if (!trackLocation || _locationStarting) return;
    _locationStarting = true;
    try {
      if (!await _locationAllowed()) return;
      if (_positions == null) _startStream();
      _maybePostLocation();
      if (_fixDue) unawaited(requestFix());
    } finally {
      _locationStarting = false;
    }
  }

  bool get _fixDue {
    final last = lastLocationSync;
    return last == null || now().difference(last) >= locationFixEvery;
  }

  /// The running one-shot fix, if any (tests await it).
  @visibleForTesting
  Future<void>? get pendingFix => _fixInFlight;

  Future<bool> _locationAllowed() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setError('location', _gpsOffText);
        return false;
      }
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setError('location', _noPermissionText);
        return false;
      }
      return true;
    } on MissingPluginException {
      return false; // Not on Android.
    } catch (e) {
      _setError('location', 'Ҷойгиршавӣ санҷида нашуд: ${_text(e)}');
      return false;
    }
  }

  void _startStream() {
    try {
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
              intervalDuration: const Duration(seconds: 30),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'NIGOH Family фаъол аст',
                notificationText:
                    'Ҷойгиршавӣ бо волидайни пайвастшуда мубодила мешавад.',
                enableWakeLock: true,
                setOngoing: true,
              ),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
            );
      _positions = Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            onPosition,
            onError: (Object e) {
              _setError('location', _fixErrorText(e));
              _positions?.cancel();
              _positions = null; // the next tick restarts the stream
              _notify();
            },
          );
    } on MissingPluginException {
      // Not on Android.
    } catch (e) {
      // The one-shot fixes keep working without the stream.
      _setError('location', 'Ҷойгиршавӣ оғоз нашуд: ${_text(e)}');
    }
  }

  static String _fixErrorText(Object e) {
    if (e is LocationServiceDisabledException) return _gpsOffText;
    if (e is PermissionDeniedException) return _noPermissionText;
    if (e is TimeoutException) return _noFixText;
    return 'Ҷойгиршавӣ муайян нашуд: ${_text(e)}';
  }

  /// One-shot fix, guarded so two never overlap.
  Future<void> requestFix() {
    return _fixInFlight ??= _requestFix().whenComplete(
      () => _fixInFlight = null,
    );
  }

  Future<void> _requestFix() async {
    if (childId == null) return;
    try {
      if (!_triedLastKnown) {
        _triedLastKnown = true;
        Position? last;
        try {
          last = await Geolocator.getLastKnownPosition();
        } on MissingPluginException {
          rethrow;
        } catch (e) {
          // A fresh fix is requested right below; its error is shown.
          debugPrint('getLastKnownPosition: $e');
        }
        if (last != null) {
          if (_lastPosition == null) {
            _lastPosition = last;
            _lastPositionSent = false;
          }
          await _post(last);
        }
      }
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: locationFixTimeLimit,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: locationFixTimeLimit,
            );
      final p = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(locationFixTimeLimit + const Duration(seconds: 5));
      _lastPosition = p;
      _lastPositionSent = false;
      await _post(p);
    } on MissingPluginException {
      // Not on Android.
    } catch (e) {
      _setError('location', _fixErrorText(e));
    } finally {
      _notify();
    }
  }

  /// New GPS fix from the stream: posted at once when allowed by the
  /// throttle, otherwise kept and posted by a later tick.
  void onPosition(Position p) {
    _lastPosition = p;
    _lastPositionSent = false;
    _maybePostLocation();
  }

  void _maybePostLocation() {
    final p = _lastPosition;
    if (p == null || childId == null) return;
    final last = _lastLocationPost;
    final since = last == null ? null : now().difference(last);
    final due =
        since == null ||
        (!_lastPositionSent && since >= locationThrottle) ||
        since >= locationHeartbeat;
    if (!due) return;
    unawaited(_post(p));
  }

  /// Posts [p] unless another post is running (then waits for that one).
  Future<void> _post(Position p) {
    return _locationInFlight ??= _postLocation(p).whenComplete(
      () => _locationInFlight = null,
    );
  }

  /// Battery level 0..100 from the phone, or null when unknown.
  Future<int?> readBattery() async {
    try {
      final level = await device.invokeMethod<int>('getBatteryLevel');
      if (level == null || level < 0 || level > 100) return null;
      batteryLevel = level;
      return level;
    } catch (e) {
      // Optional detail — location is still sent without it.
      debugPrint('getBatteryLevel: $e');
      return null;
    }
  }

  Future<void> _postLocation(Position p) async {
    final id = childId;
    if (id == null) return;
    _lastLocationPost = now();
    try {
      final battery = await readBattery();
      await api.syncLocation(id, {
        'latitude': p.latitude,
        'longitude': p.longitude,
        if (p.accuracy >= 0 && p.accuracy <= 100000) 'accuracy': p.accuracy,
        if (p.speed >= 0 && p.speed <= 1000) 'speed': p.speed,
        'battery_level': ?battery,
        'is_online': true,
      });
      if (identical(_lastPosition, p)) _lastPositionSent = true;
      lastLocationSync = now();
      _clearError('location');
    } catch (e) {
      // Allow a retry on the next tick instead of waiting the full minute.
      _lastLocationPost = null;
      _setError(
        'location',
        'Ҷойгиршавӣ ба сервер фиристода нашуд: ${_text(e)}',
      );
    } finally {
      _notify();
    }
  }

  static String _text(Object e) => e is ApiException
      ? e.message
      : e is PlatformException
      ? (e.message ?? e.code)
      : '$e';
}
