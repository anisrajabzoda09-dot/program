// Файл: интихоби бахши хонагӣ ҳангоми кушодани notification.

import 'package:flutter/foundation.dart';

/// Додаҳо ва рафтори марбут ба интихоби бахши хонагӣ ҳангоми кушодани notification-ро ифода мекунад.
class HomeTarget {
  const HomeTarget(this.kind, {this.childId});

  final String kind;
  final int? childId;

  /// forEvent мантиқи зарурии интихоби бахши хонагӣ ҳангоми кушодани notification-ро иҷро мекунад.
  static HomeTarget forEvent(String eventKind, int? childId) {
    final kind = switch (eventKind) {
      'message' || 'missed_call' => 'chat',
      'sos' || 'low_battery' || 'offline' => 'map',
      'time_request' => 'requests',
      _ => 'overview',
    };
    return HomeTarget(kind, childId: childId);
  }

  /// Ду target-ро аз рӯи навъ ва фарзанди интихобшуда муқоиса мекунад.
  @override
  bool operator ==(Object other) =>
      other is HomeTarget && other.kind == kind && other.childId == childId;

  /// Қимати ҳисобшудаи hashCode-ро аз ҳолати ҷорӣ бармегардонад.
  @override
  int get hashCode => Object.hash(kind, childId);

  /// Намоиши матнии HomeTarget-ро барои log бармегардонад.
  @override
  String toString() => 'HomeTarget($kind, child: $childId)';
}

/// Қимати homeTarget-ро барои интихоби бахши хонагӣ ҳангоми кушодани notification нигоҳ медорад.
final ValueNotifier<HomeTarget?> homeTarget = ValueNotifier(null);
