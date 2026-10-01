import 'dart:math' as math;

import '../../core/models.dart';

/// Pure helpers for the parent side (no widgets, easy to test).

enum AppCategory { games, social, education, video, other }

extension AppCategoryLabel on AppCategory {
  /// Chip label.
  String get label => switch (this) {
    AppCategory.games => 'Бозиҳо',
    AppCategory.social => 'Шабакаҳо',
    AppCategory.education => 'Маориф',
    AppCategory.video => 'Видео',
    AppCategory.other => 'Дигар',
  };

  /// Used in «Бастани ҳамаи …».
  String get pluralLower => switch (this) {
    AppCategory.games => 'бозиҳо',
    AppCategory.social => 'шабакаҳои иҷтимоӣ',
    AppCategory.education => 'барномаҳои таълимӣ',
    AppCategory.video => 'барномаҳои видео',
    AppCategory.other => 'барномаҳои дигар',
  };
}

/// Classifies an app by package-name / name keywords. Order matters: video
/// is checked before social so YouTube/TikTok land in «Видео».
AppCategory classifyApp(String packageName, [String name = '']) {
  final text = '${packageName.toLowerCase()} ${name.toLowerCase()}';
  bool any(List<String> keys) => keys.any(text.contains);

  if (any(const [
    'duolingo',
    'school',
    'academy',
    'learn',
    'khan',
    'education',
    '.edu',
    'study',
    'classroom',
    'dictionary',
    'translate',
    'math',
    'photomath',
    'quizlet',
    'brainly',
    'coursera',
    'udemy',
    'wikipedia',
    'books',
    'reader',
    'kundalik',
    'dars',
    'teacher',
    'lingua',
    'english',
  ])) {
    return AppCategory.education;
  }
  if (any(const [
    'youtube',
    'tiktok',
    'musically',
    'zhiliaoapp',
    'likee',
    'netflix',
    'twitch',
    'kinopoisk',
    'ru.ivi.',
    'okko',
    'rutube',
    'vimeo',
    'video',
    'player',
    'mxtech',
    'vlc',
    'disney',
    'primevideo',
    'wink',
    'kino',
  ])) {
    return AppCategory.video;
  }
  if (any(const [
    'game',
    'roblox',
    'minecraft',
    'mojang',
    'pubg',
    'tencent',
    'supercell',
    'freefire',
    'garena',
    'com.king.',
    'candycrush',
    'clash',
    'brawl',
    'miniclip',
    'rovio',
    'gameloft',
    'com.ea.',
    'activision',
    'mihoyo',
    'hoyoverse',
    'standoff',
    'axlebolt',
    'subway',
    'kiloo',
    'unity',
    'playrix',
    'zynga',
    'outfit7',
    'talkingtom',
    'chess',
    'puzzle',
    'arcade',
    'racing',
    'simulator',
    'innersloth',
    'moonactive',
    'voodoo',
    'ketchapp',
  ])) {
    return AppCategory.games;
  }
  if (any(const [
    'telegram',
    'whatsapp',
    'instagram',
    'facebook',
    'snapchat',
    'twitter',
    'com.x.',
    'discord',
    'vkontakte',
    'vk.',
    'odnoklassniki',
    'com.imo.',
    'viber',
    'messenger',
    'threads',
    'pinterest',
    'reddit',
    'wechat',
    'skype',
    'signal',
    'jp.naver.line',
    'kakao',
    'social',
    'chat',
    'tumblr',
    'bereal',
    'clubhouse',
    'tamtam',
    'zoom',
  ])) {
    return AppCategory.social;
  }
  return AppCategory.other;
}

AppCategory categoryOf(ChildApp app) => classifyApp(app.packageName, app.name);

// ---------- Geography ----------

/// Great-circle distance in metres (haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
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

/// The nearest safe place that contains the point, or null when outside all.
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

/// «Дар Хона» / «Берун аз ҷойҳои бехатар»; null when nothing to say.
String? placeStatus(ChildLocation? location, List<SafePlace> places) {
  if (location == null || places.isEmpty) return null;
  final inside = placeContaining(location.latitude, location.longitude, places);
  return inside != null ? 'Дар ${inside.name}' : 'Берун аз ҷойҳои бехатар';
}

// ---------- Small formatting ----------

String two(int v) => v.toString().padLeft(2, '0');

/// 'HH:mm' for a local time.
String hhmm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

/// «Вақти хоб: 21:30–07:00».
String bedtimeLabel(Bedtime b) => 'Вақти хоб: ${b.start}–${b.end}';

/// One point of the 24 h location history.
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

/// One day of the weekly report.
class UsageDay {
  const UsageDay({
    required this.date,
    required this.minutes,
    this.top = const [],
  });

  final DateTime date;
  final int minutes;
  final List<UsageTopApp> top;

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
