import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';

/// Parent-side state: the list of children from the server snapshot.
///
/// Polls every [pollInterval] while the app is in the foreground. Actions are
/// applied optimistically and rolled back on failure; the [ApiException] is
/// rethrown so the screen can show the server message.
class FamilyController extends ChangeNotifier with WidgetsBindingObserver {
  FamilyController(this.api, {this.pollInterval = const Duration(seconds: 10)});

  final NigohApi api;

  /// `null` disables polling (tests).
  final Duration? pollInterval;

  bool loading = false;
  bool loadedOnce = false;

  /// Last refresh error (also from background polling). `null` when fine.
  String? error;

  List<FamilyChild> children = const [];
  int? _selectedChildId;

  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _refreshing = false;

  /// Optimistic actions in flight; poll results are not applied meanwhile so
  /// they don't flicker the switches back.
  int _pending = 0;

  int? get selectedChildId => selected?.id;

  FamilyChild? get selected {
    if (children.isEmpty) return null;
    for (final child in children) {
      if (child.id == _selectedChildId) return child;
    }
    return children.first;
  }

  FamilyChild? childById(int id) {
    for (final child in children) {
      if (child.id == id) return child;
    }
    return null;
  }

  void select(int childId) {
    if (_selectedChildId == childId) return;
    _selectedChildId = childId;
    _notify();
  }

  /// Start loading + polling and observe the app lifecycle.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final interval = pollInterval;
    if (interval == null) return;
    _timer = Timer.periodic(interval, (_) => refresh(silent: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh(silent: true);
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Reload the snapshot. Errors are stored in [error] (never thrown) so
  /// background polling cannot crash; screens display [error] with retry.
  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      loading = true;
      _notify();
    }
    try {
      final data = await api.snapshot();
      final list = (data['children'] as List? ?? const [])
          .whereType<Map>()
          .map((c) => FamilyChild.fromJson(Map<String, dynamic>.from(c)))
          .toList();
      if (_pending == 0) children = list;
      error = null;
      loadedOnce = true;
      for (final child in list) {
        if (child.paired && !places.containsKey(child.id)) {
          places[child.id] = const [];
          // Retried on the next refresh when it fails.
          if (!await loadPlaces(child.id)) places.remove(child.id);
        }
      }
    } catch (e) {
      error = e is ApiException
          ? e.message
          : tr('Маълумот гирифта нашуд: {e}', {'e': e});
    } finally {
      _refreshing = false;
      loading = false;
      _notify();
    }
  }

  // ---------- Actions ----------

  /// Pair a child by 6-digit code. Returns the paired child when known.
  Future<FamilyChild?> pair(String code) async {
    final data = await _guard(() => api.pair(code));
    final raw = data['child'];
    final newId = raw is Map ? (raw['id'] as num?)?.toInt() : null;
    await refresh(silent: true);
    if (newId != null) {
      _selectedChildId = newId;
      _notify();
      return childById(newId);
    }
    return null;
  }

  Future<void> setBlocked(FamilyChild child, ChildApp app, bool blocked) =>
      _updateApp(child, app, _copyApp(app, blocked: blocked), {
        'is_blocked': blocked,
      });

  Future<void> setLimit(FamilyChild child, ChildApp app, int minutes) =>
      _updateApp(child, app, _copyApp(app, dailyLimitMinutes: minutes), {
        'daily_limit_minutes': minutes,
      });

  Future<void> setSchedule(
    FamilyChild child,
    ChildApp app,
    AppSchedule schedule,
  ) => _updateApp(child, app, _copyApp(app, schedule: schedule), {
    'schedule': schedule.toJson(),
  });

  /// «Ҳамеша иҷозат»: the app is never locked by pause or bedtime.
  Future<void> setAlwaysAllowed(FamilyChild child, ChildApp app, bool value) =>
      _updateApp(child, app, _copyApp(app, alwaysAllowed: value), {
        'always_allowed': value,
      });

  /// Extra minutes for today on top of the daily limit.
  Future<void> giveBonus(FamilyChild child, ChildApp app, int minutes) async {
    _replaceApp(
      child.id,
      _copyApp(app, bonusMinutesToday: app.bonusMinutesToday + minutes),
    );
    _pending++;
    _notify();
    try {
      await _guard(() => api.giveBonus(child.id, app.packageName, minutes));
    } catch (_) {
      _replaceApp(child.id, app);
      rethrow;
    } finally {
      _pending--;
      _notify();
    }
  }

  Future<void> setBedtime(FamilyChild child, Bedtime bedtime) async {
    final before = childById(child.id) ?? child;
    _replaceChild(_copyChild(before, before.apps, bedtime: bedtime));
    _pending++;
    _notify();
    try {
      await _guard(() => api.setBedtime(child.id, bedtime.toJson()));
    } catch (_) {
      _replaceChild(before);
      rethrow;
    } finally {
      _pending--;
      _notify();
    }
  }

  /// «Тамаркузи дарс»: optimistic, rolled back when the server refuses.
  Future<void> setStudyMode(FamilyChild child, StudyMode study) async {
    final before = childById(child.id) ?? child;
    _replaceChild(_copyChild(before, before.apps, study: study));
    _pending++;
    _notify();
    try {
      await _guard(() => api.setStudyMode(child.id, study.toJson()));
    } catch (_) {
      _replaceChild(before);
      rethrow;
    } finally {
      _pending--;
      _notify();
    }
  }

  /// Approve (with [minutes]) or deny an extra-time request, then reload so
  /// the badge and bonus minutes update.
  Future<void> decideRequest(
    int childId,
    int requestId, {
    required bool approve,
    int? minutes,
  }) async {
    await _guard(
      () => api.decideTimeRequest(
        childId,
        requestId,
        approve: approve,
        minutes: minutes,
      ),
    );
    await refresh(silent: true);
  }

  /// Marks the child's messages read (clears the SOS alert and unread badge).
  Future<void> markChatRead(int childId) async {
    await _guard(() => api.markChatRead(childId));
    await refresh(silent: true);
  }

  // ---------- Safe places ----------

  /// Safe places per child id (loaded once per child, then on change).
  final Map<int, List<SafePlace>> places = {};

  /// Last error while loading safe places (shown on the map).
  String? placesError;

  List<SafePlace> placesFor(int childId) => places[childId] ?? const [];

  /// Returns false on failure; the message stays in [placesError].
  Future<bool> loadPlaces(int childId) async {
    var ok = true;
    try {
      final raw = await api.safePlaces(childId);
      places[childId] = raw.map(SafePlace.fromJson).toList();
      placesError = null;
    } catch (e) {
      placesError = e is ApiException
          ? e.message
          : tr('Ҷойҳо гирифта нашуд: {e}', {'e': e});
      ok = false;
    }
    _notify();
    return ok;
  }

  Future<void> addPlace(
    int childId, {
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    await _guard(
      () => api.addSafePlace(
        childId,
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      ),
    );
    await loadPlaces(childId);
  }

  Future<void> deletePlace(int childId, SafePlace place) async {
    final before = placesFor(childId);
    places[childId] = [
      for (final p in before)
        if (p.id != place.id) p,
    ];
    _notify();
    try {
      await _guard(() => api.deleteSafePlace(childId, place.id));
    } catch (_) {
      places[childId] = before;
      _notify();
      rethrow;
    }
  }

  // ---------- Totals for badges ----------

  int get pendingRequestsTotal =>
      children.fold(0, (sum, c) => sum + c.pendingRequests);

  int get unreadTotal => children.fold(0, (sum, c) => sum + c.unreadFromChild);

  /// Children needing attention first (SOS, low battery, offline), keeping
  /// the server order otherwise.
  List<FamilyChild> get sortedByAttention {
    final indexed = [
      for (var i = 0; i < children.length; i++) (i, children[i]),
    ];
    indexed.sort((a, b) {
      final d = attentionRank(a.$2).compareTo(attentionRank(b.$2));
      return d != 0 ? d : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  List<FamilyChild> get urgentChildren => [
    for (final c in children)
      if (c.lastUrgent != null) c,
  ];

  Future<void> unlink(FamilyChild child) async {
    final before = children;
    children = [
      for (final c in children)
        if (c.id != child.id) c,
    ];
    _pending++;
    _notify();
    try {
      await _guard(() => api.unlinkChild(child.id));
    } catch (_) {
      children = before;
      rethrow;
    } finally {
      _pending--;
      _notify();
    }
  }

  Future<void> _updateApp(
    FamilyChild child,
    ChildApp original,
    ChildApp updated,
    Map<String, dynamic> rule,
  ) async {
    _replaceApp(child.id, updated);
    _pending++;
    _notify();
    try {
      await _guard(() => api.updateRule(child.id, original.packageName, rule));
    } catch (_) {
      _replaceApp(child.id, original);
      rethrow;
    } finally {
      _pending--;
      _notify();
    }
  }

  void _replaceChild(FamilyChild child) {
    children = [
      for (final c in children)
        if (c.id == child.id) child else c,
    ];
  }

  void _replaceApp(int childId, ChildApp app) {
    children = [
      for (final c in children)
        if (c.id != childId)
          c
        else
          _copyChild(c, [
            for (final a in c.apps)
              if (a.packageName == app.packageName) app else a,
          ]),
    ];
  }

  /// Converts unexpected errors to [ApiException] so callers handle one type.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(tr('Амал иҷро нашуд: {e}', {'e': e}));
    }
  }

  static ChildApp _copyApp(
    ChildApp app, {
    bool? blocked,
    int? dailyLimitMinutes,
    AppSchedule? schedule,
    bool? alwaysAllowed,
    int? bonusMinutesToday,
  }) => ChildApp(
    packageName: app.packageName,
    name: app.name,
    iconBase64: app.iconBase64,
    blocked: blocked ?? app.blocked,
    dailyLimitMinutes: dailyLimitMinutes ?? app.dailyLimitMinutes,
    usageMinutesToday: app.usageMinutesToday,
    schedule: schedule ?? app.schedule,
    alwaysAllowed: alwaysAllowed ?? app.alwaysAllowed,
    bonusMinutesToday: bonusMinutesToday ?? app.bonusMinutesToday,
    firstSeenAt: app.firstSeenAt,
  );

  static FamilyChild _copyChild(
    FamilyChild c,
    List<ChildApp> apps, {
    Bedtime? bedtime,
    StudyMode? study,
  }) => FamilyChild(
    id: c.id,
    name: c.name,
    gender: c.gender,
    age: c.age,
    paired: c.paired,
    pairingCode: c.pairingCode,
    apps: apps,
    location: c.location,
    parentName: c.parentName,
    bedtime: bedtime ?? c.bedtime,
    study: study ?? c.study,
    batteryLevel: c.batteryLevel,
    unreadFromChild: c.unreadFromChild,
    unreadFromParent: c.unreadFromParent,
    pendingRequests: c.pendingRequests,
    lastUrgent: c.lastUrgent,
  );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Battery % of the child's phone: the snapshot field, else the location's.
int? batteryOf(FamilyChild child) =>
    child.batteryLevel ?? child.location?.batteryLevel;

/// Below this battery % the parent sees a red pill.
const lowBatteryPercent = 15;

/// The phone is «Офлайн» after this long without a location report.
const offlineAfter = Duration(minutes: 20);

bool isLowBattery(FamilyChild child) {
  final b = batteryOf(child);
  return b != null && b < lowBatteryPercent;
}

/// Paired child whose phone has not reported for [offlineAfter] (or never).
bool isOfflineChild(FamilyChild child, [DateTime? now]) {
  if (!child.paired) return false;
  final at = child.location?.updatedAt;
  if (at == null) return true;
  return (now ?? DateTime.now()).toUtc().difference(at.toUtc()) > offlineAfter;
}

/// 0 = SOS, 1 = low battery, 2 = offline, 3 = fine.
int attentionRank(FamilyChild child, [DateTime? now]) {
  if (child.lastUrgent != null) return 0;
  if (isLowBattery(child)) return 1;
  if (isOfflineChild(child, now)) return 2;
  return 3;
}

/// «1с 25д», «40 дақ».
String formatMinutes(int minutes) {
  if (minutes < 60) return tr('{minutes} дақ', {'minutes': minutes});
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? tr('{hours} соат', {'hours': hours})
      : tr('{hours}с {rest}д', {'hours': hours, 'rest': rest});
}
