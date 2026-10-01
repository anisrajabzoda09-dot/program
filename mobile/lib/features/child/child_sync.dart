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
  }) : device = deviceChannel ?? const MethodChannel('tj.nigoh/device_control'),
       _packageEventsChannel =
           packageEvents ?? const EventChannel('tj.nigoh/package_events'),
       _loadProfile = loadProfile ?? ChildProfile.load;

  final NigohApi api;
  final MethodChannel device;
  final EventChannel _packageEventsChannel;
  final Future<ChildProfile?> Function() _loadProfile;
  final bool trackLocation;
  final bool listenPackageEvents;

  static const pollInterval = Duration(seconds: 15);
  static const appsInterval = Duration(minutes: 10);
  static const locationThrottle = Duration(seconds: 60);
  static const locationHeartbeat = Duration(minutes: 5);

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
    final wasPaired = paired;
    childId = child.id;
    pairingCode = child.pairingCode.isEmpty ? pairingCode : child.pairingCode;
    paired = child.paired;
    parentName = (child.parentName?.trim().isEmpty ?? true)
        ? null
        : child.parentName!.trim();
    if (paired && !wasPaired) _appsDirty = true;
    // After an unlink the phone must stop enforcing old rules.
    await pushRules(paired ? child.apps : const []);
  }

  /// Sends the parent's rules to the native blocker.
  Future<void> pushRules(List<ChildApp> apps) async {
    try {
      await device.invokeMethod<void>('setAppControlRules', {
        'rules': apps.map((a) => a.toNativeRule()).toList(),
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
      if (trackLocation) {
        if (_positions == null) unawaited(startLocation());
        _maybePostLocation();
      }
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

  Future<void> startLocation() async {
    if (!trackLocation || _positions != null || _locationStarting) return;
    _locationStarting = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setError(
          'location',
          'GPS хомӯш аст — ҷойгиршавӣ фиристода намешавад.',
        );
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setError('location', 'Иҷозати ҷойгиршавӣ дода нашудааст.');
        return;
      }
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
              _setError('location', 'Ҷойгиршавӣ муайян нашуд: ${_text(e)}');
              _positions?.cancel();
              _positions = null; // the next tick restarts the stream
              _notify();
            },
          );
    } on MissingPluginException {
      // Not on Android.
    } catch (e) {
      _setError('location', 'Ҷойгиршавӣ оғоз нашуд: ${_text(e)}');
    } finally {
      _locationStarting = false;
      _notify();
    }
  }

  /// New GPS fix: posted at once when allowed by the throttle, otherwise
  /// kept and posted by a later tick.
  void onPosition(Position p) {
    _lastPosition = p;
    _lastPositionSent = false;
    _maybePostLocation();
  }

  void _maybePostLocation() {
    final p = _lastPosition;
    if (p == null || childId == null) return;
    final last = _lastLocationPost;
    final since = last == null ? null : DateTime.now().difference(last);
    final due =
        since == null ||
        (!_lastPositionSent && since >= locationThrottle) ||
        since >= locationHeartbeat;
    if (!due) return;
    _locationInFlight ??= _postLocation(p)
        .whenComplete(() => _locationInFlight = null);
  }

  Future<void> _postLocation(Position p) async {
    final id = childId;
    if (id == null) return;
    _lastLocationPost = DateTime.now();
    try {
      await api.syncLocation(id, {
        'latitude': p.latitude,
        'longitude': p.longitude,
        if (p.accuracy >= 0 && p.accuracy <= 100000) 'accuracy': p.accuracy,
        if (p.speed >= 0 && p.speed <= 1000) 'speed': p.speed,
        'is_online': true,
      });
      if (identical(_lastPosition, p)) _lastPositionSent = true;
      lastLocationSync = DateTime.now();
      _clearError('location');
    } catch (e) {
      // Allow a retry on the next tick instead of waiting the full minute.
      _lastLocationPost = null;
      _setError('location', 'Ҷойгиршавӣ фиристода нашуд: ${_text(e)}');
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
