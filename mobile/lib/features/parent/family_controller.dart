// Файл: боркунӣ ва навсозии ҳолати оила.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';

/// Мантиқ ва ҳолати боркунӣ ва навсозии ҳолати оиларо идора мекунад.
class FamilyController extends ChangeNotifier with WidgetsBindingObserver {
  FamilyController(this.api, {this.pollInterval = const Duration(seconds: 10)});

  final NigohApi api;

  /// Қимати pollInterval-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад.
  final Duration? pollInterval;

  bool loading = false;
  bool loadedOnce = false;

  /// Қимати error-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад.
  String? error;

  List<FamilyChild> children = const [];
  int? _selectedChildId;

  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _refreshing = false;

  /// Қимати _pending-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад.
  int _pending = 0;

  /// Қимати ҳисобшудаи selectedChildId-ро аз ҳолати ҷорӣ бармегардонад.
  int? get selectedChildId => selected?.id;

  /// Қимати ҳисобшудаи selected-ро барои боркунӣ ва навсозии ҳолати оила бармегардонад.
  FamilyChild? get selected {
    if (children.isEmpty) return null;
    for (final child in children) {
      if (child.id == _selectedChildId) return child;
    }
    return children.first;
  }

  /// childById мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
  FamilyChild? childById(int id) {
    for (final child in children) {
      if (child.id == id) return child;
    }
    return null;
  }

  /// select ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  void select(int childId) {
    if (_selectedChildId == childId) return;
    _selectedChildId = childId;
    _notify();
  }

  /// start раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _startTimer();
  }

  /// startTimer раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void _startTimer() {
    _timer?.cancel();
    final interval = pollInterval;
    if (interval == null) return;
    _timer = Timer.periodic(interval, (_) => refresh(silent: true));
  }

  /// Ба тағйири lifecycle-и FamilyController ҷавоб медиҳад.
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

  /// refresh додаҳои ҳолати оила-ро боз мехонад ва FamilyController-ро нав мекунад.
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
          // Ҳангоми нокомӣ роҳи эҳтиётӣ истифода мешавад.
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

  // Қадами дохилии боркунӣ ва навсозии ҳолати оила.

  /// pair дархостро ба API мефиристад ва натиҷаро коркард мекунад.
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

  /// setBlocked ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> setBlocked(FamilyChild child, ChildApp app, bool blocked) =>
      _updateApp(child, app, _copyApp(app, blocked: blocked), {
        'is_blocked': blocked,
      });

  /// setLimit ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> setLimit(FamilyChild child, ChildApp app, int minutes) =>
      _updateApp(child, app, _copyApp(app, dailyLimitMinutes: minutes), {
        'daily_limit_minutes': minutes,
      });

  /// setSchedule ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> setSchedule(
    FamilyChild child,
    ChildApp app,
    AppSchedule schedule,
  ) => _updateApp(child, app, _copyApp(app, schedule: schedule), {
    'schedule': schedule.toJson(),
  });

  /// setAlwaysAllowed ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> setAlwaysAllowed(FamilyChild child, ChildApp app, bool value) =>
      _updateApp(child, app, _copyApp(app, alwaysAllowed: value), {
        'always_allowed': value,
      });

  /// giveBonus дархостро ба API мефиристад ва натиҷаро коркард мекунад.
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

  /// setBedtime ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
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

  /// setStudyMode ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
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

  /// decideRequest дархостро ба API мефиристад ва натиҷаро коркард мекунад.
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

  /// markChatRead дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> markChatRead(int childId) async {
    await _guard(() => api.markChatRead(childId));
    await refresh(silent: true);
  }

  // Қадами дохилии боркунӣ ва навсозии ҳолати оила.

  /// Қимати places-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад.
  final Map<int, List<SafePlace>> places = {};

  /// Қимати placesError-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад.
  String? placesError;

  /// placesFor мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
  List<SafePlace> placesFor(int childId) => places[childId] ?? const [];

  /// loadPlaces додаҳоро мехонад ва ҳолати экранро нав мекунад.
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

  /// addPlace мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
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

  /// deletePlace маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
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

  // Қадами дохилии боркунӣ ва навсозии ҳолати оила.

  /// Қимати ҳисобшудаи pendingRequestsTotal-ро аз ҳолати ҷорӣ бармегардонад.
  int get pendingRequestsTotal =>
      children.fold(0, (sum, c) => sum + c.pendingRequests);

  /// Қимати ҳисобшудаи unreadTotal-ро аз ҳолати ҷорӣ бармегардонад.
  int get unreadTotal => children.fold(0, (sum, c) => sum + c.unreadFromChild);

  /// Қимати ҳисобшудаи sortedByAttention-ро барои боркунӣ ва навсозии ҳолати оила бармегардонад.
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

  /// Қимати urgentChildren-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад.
  List<FamilyChild> get urgentChildren => [
    for (final c in children)
      if (c.lastUrgent != null) c,
  ];

  /// unlink маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
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

  /// updateApp ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
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

  /// replaceChild мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
  void _replaceChild(FamilyChild child) {
    children = [
      for (final c in children)
        if (c.id == child.id) child else c,
    ];
  }

  /// replaceApp мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
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

  /// T мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(tr('Амал иҷро нашуд: {e}', {'e': e}));
    }
  }

  /// copyApp мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
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

  /// copyChild мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
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

  /// notify listener ё корбарро аз тағйирот огоҳ мекунад.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Controller ва listener-ҳои FamilyController-ро озод мекунад.
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// batteryOf мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
int? batteryOf(FamilyChild child) =>
    child.batteryLevel ?? child.location?.batteryLevel;

/// Қимати lowBatteryPercent-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад.
const lowBatteryPercent = 15;

/// Қимати offlineAfter-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад.
const offlineAfter = Duration(minutes: 20);

/// isLowBattery иҷро шудани шарти вобастаро муайян мекунад.
bool isLowBattery(FamilyChild child) {
  final b = batteryOf(child);
  return b != null && b < lowBatteryPercent;
}

/// isOfflineChild иҷро шудани шарти вобастаро муайян мекунад.
bool isOfflineChild(FamilyChild child, [DateTime? now]) {
  if (!child.paired) return false;
  final at = child.location?.updatedAt;
  if (at == null) return true;
  return (now ?? DateTime.now()).toUtc().difference(at.toUtc()) > offlineAfter;
}

/// attentionRank мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад.
int attentionRank(FamilyChild child, [DateTime? now]) {
  if (child.lastUrgent != null) return 0;
  if (isLowBattery(child)) return 1;
  if (isOfflineChild(child, now)) return 2;
  return 3;
}

/// formatMinutes додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад.
String formatMinutes(int minutes) {
  if (minutes < 60) return tr('{minutes} дақ', {'minutes': minutes});
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? tr('{hours} соат', {'hours': hours})
      : tr('{hours} соат {rest} дақ', {'hours': hours, 'rest': rest});
}
