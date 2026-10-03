// Файл: ҳисобҳо ва қарорҳои интерфейси волид.

import 'dart:math' as math;

import '../../core/models.dart';

export '../../core/app_categories.dart';
import '../../l10n/l10n.dart';

// Қадами дохилии ҳисобҳо ва қарорҳои интерфейси волид.

/// distanceMeters қимати заруриро аз додаҳои ҷорӣ ҳисоб мекунад.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  /// rad мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// placeContaining мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
SafePlace? placeContaining(
  double latitude,
  double longitude,
  List<SafePlace> places,
) {
  SafePlace? best;
  var bestDistance = double.infinity;
  for (final place in places) {
    final d = distanceMeters(
      latitude,
      longitude,
      place.latitude,
      place.longitude,
    );
    if (d <= place.radiusMeters && d < bestDistance) {
      best = place;
      bestDistance = d;
    }
  }
  return best;
}

/// placeStatus мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
String? placeStatus(ChildLocation? location, List<SafePlace> places) {
  if (location == null || places.isEmpty) return null;
  final inside = placeContaining(location.latitude, location.longitude, places);
  return inside != null
      ? tr('Дар {name}', {'name': inside.name})
      : tr('Берун аз ҷойҳои бехатар');
}

// Қадами дохилии ҳисобҳо ва қарорҳои интерфейси волид.

/// two мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
String two(int v) => v.toString().padLeft(2, '0');

/// hhmm мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
String hhmm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

/// bedtimeLabel мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
String bedtimeLabel(Bedtime b) =>
    tr('Вақти хоб: {start}–{end}', {'start': b.start, 'end': b.end});

/// Додаҳо ва рафтори марбут ба ҳисобҳо ва қарорҳои интерфейси волидро ифода мекунад.
class HistoryPoint {
  const HistoryPoint({
    required this.latitude,
    required this.longitude,
    this.time,
    this.batteryLevel,
  });

  final double latitude;
  final double longitude;
  final DateTime? time;
  final int? batteryLevel;

  /// listFromJson мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
  static List<HistoryPoint> listFromJson(List<Map<String, dynamic>> raw) {
    final out = <HistoryPoint>[];
    for (final p in raw) {
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      out.add(
        HistoryPoint(
          latitude: lat,
          longitude: lng,
          time: _time(p['created_at'] ?? p['recorded_at'] ?? p['updated_at']),
          batteryLevel: (p['battery_level'] as num?)?.toInt(),
        ),
      );
    }
    out.sort((a, b) {
      final ta = a.time, tb = b.time;
      if (ta == null || tb == null) return 0;
      return ta.compareTo(tb);
    });
    return out;
  }

  /// time мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
  static DateTime? _time(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final iso = text.contains('T') ? text : text.replaceFirst(' ', 'T');
    final hasZone =
        iso.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(iso);
    return DateTime.tryParse(hasZone ? iso : '${iso}Z');
  }
}

/// Додаҳо ва рафтори марбут ба ҳисобҳо ва қарорҳои интерфейси волидро ифода мекунад.
class UsageDay {
  const UsageDay({
    required this.date,
    required this.minutes,
    this.top = const [],
  });

  final DateTime date;
  final int minutes;
  final List<UsageTopApp> top;

  /// listFromJson мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
  static List<UsageDay> listFromJson(List<Map<String, dynamic>> raw) => [
    for (final d in raw)
      UsageDay(
        date: DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now(),
        minutes: (d['minutes'] as num?)?.toInt() ?? 0,
        top: [
          for (final t in (d['top'] as List? ?? const []).whereType<Map>())
            UsageTopApp(
              packageName: t['package_name']?.toString() ?? '',
              name:
                  t['app_name']?.toString() ??
                  t['package_name']?.toString() ??
                  '',
              minutes: (t['minutes'] as num?)?.toInt() ?? 0,
            ),
        ],
      ),
  ];
}

/// Додаҳо ва рафтори марбут ба ҳисобҳо ва қарорҳои интерфейси волидро ифода мекунад.
class UsageTopApp {
  const UsageTopApp({
    required this.packageName,
    required this.name,
    required this.minutes,
  });
  final String packageName;
  final String name;
  final int minutes;
}

const weekdayShort = ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш'];

/// limitLabelText мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад.
String limitLabelText(int minutes) {
  if (minutes <= 0) return tr('Бе лимит');
  if (minutes < 60) return tr('{minutes}д', {'minutes': minutes});
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? tr('{hours}с', {'hours': hours})
      : tr('{hours}с {rest}д', {'hours': hours, 'rest': rest});
}
