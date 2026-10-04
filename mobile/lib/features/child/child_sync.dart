// Файл: ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/child_profile.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';

/// Додаҳо ва рафтори марбут ба ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро ифода мекунад.
class ChildSync extends ChangeNotifier {
  ChildSync({
    required this.api,
    MethodChannel? deviceChannel,
    EventChannel? packageEvents,

    /// Function мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
    Future<ChildProfile?> Function()? loadProfile,
    this.trackLocation = true,
    this.listenPackageEvents = true,

    /// Function мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
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

  /// now мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  DateTime now() => _clock();

  static const pollInterval = Duration(seconds: 15);
  static const appsInterval = Duration(minutes: 10);
  static const locationThrottle = Duration(seconds: 60);
  static const locationHeartbeat = Duration(minutes: 5);

  /// Қимати locationFixEvery-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  static const locationFixEvery = Duration(seconds: 60);
  static const locationFixTimeLimit = Duration(seconds: 20);

  /// clampUsage мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  static int clampUsage(Object? minutes) =>
      ((minutes as num?)?.toInt() ?? 0).clamp(0, 1440);

  // Ҳолати пайвастшавӣ, ҳамоҳангсозӣ ва хатогиҳои намоёни телефони фарзанд.

  /// Қимати loading-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
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

  /// Қимати child-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  FamilyChild? child;

  /// Қимати batteryLevel-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  int? batteryLevel;

  /// Қимати lastPosition-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  Position? get lastPosition => _lastPosition;

  /// Қимати protection-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  Map<String, dynamic> protection = const {};

  /// Қимати protectionKnown-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  bool protectionKnown = false;

  /// Қимати missingPermissions-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  List<String> missingPermissions = const [];

  final _errors =
      <String, String>{}; // Тартиби воридшавии хатогиҳо нигоҳ дошта мешавад.

  /// Қимати lastError-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  String? get lastError => _errors.isEmpty ? null : _errors.values.last;

  // Timer, stream ва future-ҳои дохилиро барои пешгирии кори такрорӣ нигоҳ медорад.

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

  /// setError ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  void _setError(String area, Object error) {
    _errors.remove(area);
    _errors[area] = error is String ? error : _text(error);
  }

  /// clearError маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
  void _clearError(String area) => _errors.remove(area);

  /// notify listener ё корбарро аз тағйирот огоҳ мекунад.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // Даври polling ва шунидани тағйири package-ҳои Android-ро оғоз мекунад.

  /// start раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
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

  /// stop раванди фаъолро қатъ карда, захираҳои онро озод мекунад.
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

  /// Controller ва listener-ҳои ChildSync-ро озод мекунад.
  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }

  /// forceSync мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  Future<void> forceSync() async {
    _appsDirty = true;
    await tick();
    if (_tickInFlight != null) await _tickInFlight;
    if (_appsInFlight != null) await _appsInFlight;
  }

  // Профили фарзандро танҳо бо як дархости ҳамзамон таъмин мекунад.

  /// ensureChild дурустӣ ва шартҳои зарурии додаҳоро месанҷад.
  Future<void> ensureChild() {
    return _ensureInFlight ??= _ensureChild().whenComplete(
      () => _ensureInFlight = null,
    );
  }

  /// ensureChild дурустӣ ва шартҳои зарурии додаҳоро месанҷад.
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

  /// createCode мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  Future<void> _createCode() async {
    final profile = await _loadProfile();
    final data = await api.createPairCode(
      childName: (profile?.name.trim().isNotEmpty ?? false)
          ? profile!.name.trim()
          : tr('Фарзанд'),
      gender: profile?.gender ?? 'boy',
      age: profile?.age ?? 11,
    );
    childId = (data['child_id'] as num?)?.toInt() ?? childId;
    pairingCode = data['pairing_code']?.toString() ?? pairingCode;
    final nowPaired = data['paired'] == true;
    if (nowPaired && !paired) _appsDirty = true;
    paired = nowPaired;
  }

  /// regenerateCode мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
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

  /// applyChild рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
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
    // Қоидаҳои навгирифтаро фавран ба blocker-и Android мефиристад.
    await pushRules(
      paired ? child.apps : const [],
      bedtime: paired ? child.bedtime : const Bedtime(),
      study: paired ? child.study : const StudyMode(),
    );
    await applyWebFilter(paired ? child.webFilter : const WebFilter());
  }

  /// Ҳолати филтри сайтҳо дар ҳамин телефон: active, off ё needs_permission.
  String? webFilterState;

  /// Ҳолате, ки охирин бор ба сервер фиристода шуд (то такрор нашавад).
  String? _reportedWebFilterState;

  /// Филтри сайтҳоро ба VPN-и Android месупорад ва ҳолатро ба волидайн хабар медиҳад.
  Future<void> applyWebFilter(WebFilter filter) async {
    try {
      final state = await device.invokeMethod<String>('setWebFilter', {
        'level': filter.level,
        'blocked': filter.blocked,
      });
      webFilterState = state;
      await _reportWebFilterState(filter, state);
    } on MissingPluginException {
      // Дар муҳити бе plugin (санҷишҳо) филтр танҳо дар сервер мемонад.
    } catch (e) {
      debugPrint('setWebFilter: $e');
    }
  }

  /// Тирезаи розигии VPN-ро нишон медиҳад; пас аз розигӣ филтр фавран кор мекунад.
  Future<bool> requestWebFilterPermission() async {
    try {
      final ok =
          await device.invokeMethod<bool>('requestWebFilterPermission') ??
          false;
      final c = child;
      if (c != null) await applyWebFilter(c.webFilter);
      _notify();
      return ok;
    } on MissingPluginException {
      return false;
    }
  }

  /// Ҳолати навро танҳо вақте мефиристад, ки аз ҳолати маълуми сервер фарқ дорад.
  Future<void> _reportWebFilterState(WebFilter filter, String? state) async {
    final id = childId;
    if (id == null || state == null) return;
    if (state == filter.state) {
      _reportedWebFilterState = state;
      return;
    }
    if (state == _reportedWebFilterState) return;
    // Филтре, ки волидайн нагузоштаанд ва сервер ҳолаташро намедонад, хабар лозим нест.
    if (!filter.enabled && filter.state == null) return;
    try {
      await api.reportWebFilterState(id, state);
      _reportedWebFilterState = state;
    } catch (e) {
      debugPrint('reportWebFilterState: $e');
    }
  }

  /// pushRules мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  Future<void> pushRules(
    List<ChildApp> apps, {
    Bedtime bedtime = const Bedtime(),
    StudyMode study = const StudyMode(),
  }) async {
    final at = now();
    final bedtimeActive = bedtime.activeAt(at);
    final studyActive = study.activeAt(at);
    _pushedWindows = (bedtimeActive, studyActive);
    try {
      await device.invokeMethod<void>('setAppControlRules', {
        'rules': apps
            .map(
              (a) => a.toNativeRule(
                bedtimeActive: bedtimeActive,
                studyActive: studyActive,
              ),
            )
            .toList(),
      });
      rulesCount = apps.length;
      lastRulesSync = DateTime.now();
      _clearError('rules');
    } on MissingPluginException {
      // Дар муҳити бе plugin қоидаҳо танҳо дар сервер боқӣ мемонанд.
    } catch (e) {
      _setError(
        'rules',
        tr('Қоидаҳо дар телефон татбиқ нашуданд: {error}', {'error': _text(e)}),
      );
    }
  }

  /// Фаъолии охирини реҷаи хоб ва дарсро барои ошкор кардани гузариши вақт нигоҳ медорад.
  (bool, bool)? _pushedWindows;

  /// repushIfWindowChanged мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  Future<void> _repushIfWindowChanged() async {
    final c = child;
    if (c == null || !paired) return;
    final at = now();
    final windows = (c.bedtime.activeAt(at), c.study.activeAt(at));
    if (windows == _pushedWindows) return;
    await pushRules(c.apps, bedtime: c.bedtime, study: c.study);
  }

  // Як даври ҳамоҳангсозиро бе иҷрои ду future-и ҳамзамон мегузаронад.

  /// tick мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  Future<void> tick() {
    return _tickInFlight ??= _tick().whenComplete(() => _tickInFlight = null);
  }

  /// tick мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
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
        await _repushIfWindowChanged();
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

  // Вазъи usage access, overlay, Accessibility ва батареяро аз Android мехонад.

  /// refreshProtection додаҳоро боз хонда, интерфейсро нав мекунад.
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
      // Дар муҳити бе plugin вазъи муҳофизати Android дастнорас мемонад.
    } catch (e) {
      _setError(
        'protection',
        tr('Ҳолати иҷозатҳо санҷида нашуд: {error}', {'error': _text(e)}),
      );
    }
  }

  // Рӯйхати барномаҳо ва омори истифодаи онҳоро бо сервер ҳамоҳанг месозад.

  /// syncApps додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад.
  Future<void> syncApps() {
    return _appsInFlight ??= _syncApps().whenComplete(
      () => _appsInFlight = null,
    );
  }

  /// syncApps додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад.
  Future<void> _syncApps() async {
    final id = childId;
    if (id == null) return;
    try {
      final apps = await buildAppsPayload();
      if (apps.isEmpty) {
        throw ApiException(tr('Рӯйхати барномаҳои телефон гирифта нашуд.'));
      }
      await api.syncApps(id, apps);
      appsCount = apps.length;
      lastAppsSync = DateTime.now();
      _appsDirty = false;
      _clearError('apps');
    } catch (e) {
      // Пас аз хатои фиристодан рӯйхати барномаҳоро барои кӯшиши навбатӣ dirty мемонад.
      _appsDirty = true;
      _setError(
        'apps',
        tr('Барномаҳо фиристода нашуданд: {error}', {'error': _text(e)}),
      );
    } finally {
      _notify();
    }
  }

  /// buildAppsPayload қисми мувофиқи интерфейсро месозад.
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
      // Нокомии хондани омори истифода сабт мешавад, вале рӯйхати барномаҳо идома меёбад.
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

  // Матнҳои хатои GPS ва иҷозати ҷойгиршавиро барои фарзанд таъмин мекунад.

  /// Қимати ҳисобшудаи gpsOffText-ро аз ҳолати ҷорӣ бармегардонад.
  static String get _gpsOffText => tr(
    'GPS хомӯш аст — ҷойгиршавӣ фиристода намешавад. Онро дар танзимоти телефон фаъол кунед.',
  );

  /// Қимати ҳисобшудаи noPermissionText-ро аз ҳолати ҷорӣ бармегардонад.
  static String get _noPermissionText =>
      tr('Иҷозати ҷойгиршавӣ дода нашудааст — волидайн ҷои шуморо намебинанд.');

  /// Қимати ҳисобшудаи noFixText-ро аз ҳолати ҷорӣ бармегардонад.
  static String get _noFixText =>
      tr('Ҷойгиршавӣ ҳоло муайян нашуд (сигнали GPS нест). Боз кӯшиш мекунем.');

  /// startLocation раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
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

  /// Қимати ҳисобшудаи fixDue-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо бармегардонад.
  bool get _fixDue {
    final last = lastLocationSync;
    return last == null || now().difference(last) >= locationFixEvery;
  }

  /// Қимати pendingFix-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад.
  @visibleForTesting
  Future<void>? get pendingFix => _fixInFlight;

  /// locationAllowed мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
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
      return false; // Дар платформаи ғайри Android дастгирӣ намешавад.
    } catch (e) {
      _setError(
        'location',
        tr('Ҷойгиршавӣ санҷида нашуд: {error}', {'error': _text(e)}),
      );
      return false;
    }
  }

  /// startStream раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void _startStream() {
    try {
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
              intervalDuration: const Duration(seconds: 30),
              foregroundNotificationConfig: ForegroundNotificationConfig(
                notificationTitle: tr('NIGOH Family фаъол аст'),
                notificationText: tr(
                  'Ҷойгиршавӣ бо волидайни пайвастшуда мубодила мешавад.',
                ),
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
              _positions = null; // Даври навбатӣ stream-ро аз нав оғоз мекунад.
              _notify();
            },
          );
    } on MissingPluginException {
      // Дар муҳити бе plugin пайгирии GPS оғоз намешавад.
    } catch (e) {
      _setError(
        'location',
        tr('Ҷойгиршавӣ оғоз нашуд: {error}', {'error': _text(e)}),
      );
    }
  }

  /// fixErrorText мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  static String _fixErrorText(Object e) {
    if (e is LocationServiceDisabledException) return _gpsOffText;
    if (e is PermissionDeniedException) return _noPermissionText;
    if (e is TimeoutException) return _noFixText;
    return tr('Ҷойгиршавӣ муайян нашуд: {error}', {'error': _text(e)});
  }

  /// requestFix иҷозат ё маълумоти лозимро дархост мекунад.
  Future<void> requestFix() {
    return _fixInFlight ??= _requestFix().whenComplete(
      () => _fixInFlight = null,
    );
  }

  /// requestFix иҷозат ё маълумоти лозимро дархост мекунад.
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
          // Хатои гирифтани ҷойгиршавии охиринро сабт карда, stream-ро идома медиҳад.
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
      final p = await Geolocator.getCurrentPosition(locationSettings: settings)
          .timeout(locationFixTimeLimit + const Duration(seconds: 5));
      _lastPosition = p;
      _lastPositionSent = false;
      await _post(p);
    } on MissingPluginException {
      // Дар муҳити бе plugin ҷойгиршавии якдафъаина гирифта намешавад.
    } catch (e) {
      _setError('location', _fixErrorText(e));
    } finally {
      _notify();
    }
  }

  /// onPosition рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void onPosition(Position p) {
    _lastPosition = p;
    _lastPositionSent = false;
    _maybePostLocation();
  }

  /// maybePostLocation мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
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

  /// post мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  Future<void> _post(Position p) {
    return _locationInFlight ??= _postLocation(p)
        .whenComplete(() => _locationInFlight = null);
  }

  /// readBattery додаҳоро мехонад ва ҳолати экранро нав мекунад.
  Future<int?> readBattery() async {
    try {
      final level = await device.invokeMethod<int>('getBatteryLevel');
      if (level == null || level < 0 || level > 100) return null;
      batteryLevel = level;
      return level;
    } catch (e) {
      // Хатои хондани фоизи батареяро сабт карда, қимати номаълум бармегардонад.
      debugPrint('getBatteryLevel: $e');
      return null;
    }
  }

  /// postLocation мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
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
      // Пас аз хатои API вақти фиристодани ҷойгиршавиро пок мекунад, то дубора кӯшиш шавад.
      _lastLocationPost = null;
      _setError(
        'location',
        tr('Ҷойгиршавӣ ба сервер фиристода нашуд: {error}', {
          'error': _text(e),
        }),
      );
    } finally {
      _notify();
    }
  }

  /// text мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад.
  static String _text(Object e) => e is ApiException
      ? e.message
      : e is PlatformException
      ? (e.message ?? e.code)
      : '$e';
}
