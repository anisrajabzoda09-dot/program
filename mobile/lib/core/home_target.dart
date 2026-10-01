import 'package:flutter/foundation.dart';

/// Where a home screen should jump after the app was opened from a
/// notification (set by main.dart from [NotifyBridge.launch]).
///
/// kind: 'chat' | 'map' | 'overview' | 'requests'.
/// Parent/child homes may listen to [homeTarget], switch to the matching tab
/// (and child, when [childId] is set), then reset it to null.
/// Mapping used by main.dart:
///   message, missed_call → chat; sos, low_battery, offline → map;
///   time_request → requests; time_decision, new_app, other → overview.
class HomeTarget {
  const HomeTarget(this.kind, {this.childId});

  final String kind;
  final int? childId;

  /// Maps a server event kind to a home target.
  static HomeTarget forEvent(String eventKind, int? childId) {
    final kind = switch (eventKind) {
      'message' || 'missed_call' => 'chat',
      'sos' || 'low_battery' || 'offline' => 'map',
      'time_request' => 'requests',
      _ => 'overview',
    };
    return HomeTarget(kind, childId: childId);
  }

  @override
  bool operator ==(Object other) =>
      other is HomeTarget && other.kind == kind && other.childId == childId;

  @override
  int get hashCode => Object.hash(kind, childId);

  @override
  String toString() => 'HomeTarget($kind, child: $childId)';
}

/// The pending jump target; null when nothing is pending.
final ValueNotifier<HomeTarget?> homeTarget = ValueNotifier(null);
