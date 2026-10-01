import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/api.dart';
import '../../core/models.dart';

/// Parent-side state: the list of children from the server snapshot.
///
/// Polls every [pollInterval] while the app is in the foreground. Actions are
/// applied optimistically and rolled back on failure; the [ApiException] is
/// rethrown so the screen can show the server message.
class FamilyController extends ChangeNotifier with WidgetsBindingObserver {
  FamilyController(
    this.api, {
    this.pollInterval = const Duration(seconds: 10),
  });

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
    } catch (e) {
      error = e is ApiException ? e.message : 'Маълумот гирифта нашуд: $e';
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
      _updateApp(
        child,
        app,
        _copyApp(app, blocked: blocked),
        {'is_blocked': blocked},
      );

  Future<void> setLimit(FamilyChild child, ChildApp app, int minutes) =>
      _updateApp(
        child,
        app,
        _copyApp(app, dailyLimitMinutes: minutes),
        {'daily_limit_minutes': minutes},
      );

  Future<void> setSchedule(
    FamilyChild child,
    ChildApp app,
    AppSchedule schedule,
  ) => _updateApp(
    child,
    app,
    _copyApp(app, schedule: schedule),
    {'schedule': schedule.toJson()},
  );

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
      throw ApiException('Амал иҷро нашуд: $e');
    }
  }

  static ChildApp _copyApp(
    ChildApp app, {
    bool? blocked,
    int? dailyLimitMinutes,
    AppSchedule? schedule,
  }) => ChildApp(
    packageName: app.packageName,
    name: app.name,
    iconBase64: app.iconBase64,
    blocked: blocked ?? app.blocked,
    dailyLimitMinutes: dailyLimitMinutes ?? app.dailyLimitMinutes,
    usageMinutesToday: app.usageMinutesToday,
    schedule: schedule ?? app.schedule,
  );

  static FamilyChild _copyChild(FamilyChild c, List<ChildApp> apps) =>
      FamilyChild(
        id: c.id,
        name: c.name,
        gender: c.gender,
        age: c.age,
        paired: c.paired,
        pairingCode: c.pairingCode,
        apps: apps,
        location: c.location,
        parentName: c.parentName,
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

/// «1с 25д», «40 дақ».
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes дақ';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours соат' : '$hoursс $restд';
}
