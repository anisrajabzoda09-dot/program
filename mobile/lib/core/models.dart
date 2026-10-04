// Файл: model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ.

import '../ui/widgets.dart' show parseServerTime;
import 'app_categories.dart';
import '../l10n/l10n.dart';

/// AppSchedule додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class AppSchedule {
  const AppSchedule({
    this.enabled = false,
    this.start = '16:00',
    this.end = '18:00',
    this.weekdays = const [1, 2, 3, 4, 5],
  });

  final bool enabled;
  final String start;
  final String end;
  final List<int> weekdays;

  /// AppSchedule-ро аз JSON-и сервер месозад.
  factory AppSchedule.fromJson(Object? raw) {
    if (raw is! Map) return const AppSchedule();
    return AppSchedule(
      enabled: raw['enabled'] == true,
      start: raw['start']?.toString() ?? '16:00',
      end: raw['end']?.toString() ?? '18:00',
      weekdays: (raw['weekdays'] as List? ?? const [1, 2, 3, 4, 5])
          .map((d) => (d as num).toInt())
          .toList(),
    );
  }

  /// Объектро ба сохтори JSON барои API табдил медиҳад.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
    'weekdays': weekdays,
  };
}

/// ChildApp додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class ChildApp {
  const ChildApp({
    required this.packageName,
    required this.name,
    this.iconBase64 = '',
    this.blocked = false,
    this.dailyLimitMinutes = 0,
    this.usageMinutesToday = 0,
    this.schedule = const AppSchedule(),
    this.alwaysAllowed = false,
    this.bonusMinutesToday = 0,
    this.firstSeenAt,
  });

  final bool alwaysAllowed;
  final int bonusMinutesToday;
  final DateTime? firstSeenAt;

  /// Қимати effectiveLimitMinutes-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад.
  int get effectiveLimitMinutes =>
      dailyLimitMinutes == 0 ? 0 : dailyLimitMinutes + bonusMinutesToday;

  /// Қимати isNew-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад.
  bool get isNew =>
      firstSeenAt != null &&
      DateTime.now().toUtc().difference(firstSeenAt!.toUtc()).inHours < 24;

  final String packageName;
  final String name;
  final String iconBase64;
  final bool blocked;
  final int dailyLimitMinutes;
  final int usageMinutesToday;
  final AppSchedule schedule;

  /// ChildApp-ро аз JSON-и сервер месозад.
  factory ChildApp.fromJson(Map<String, dynamic> j) => ChildApp(
    packageName: j['package_name']?.toString() ?? '',
    name: j['app_name']?.toString() ?? j['package_name']?.toString() ?? '',
    iconBase64: j['app_icon']?.toString() ?? '',
    blocked: j['is_blocked'] == true || j['is_blocked'] == 1,
    dailyLimitMinutes: (j['daily_limit_minutes'] as num?)?.toInt() ?? 0,
    usageMinutesToday: (j['usage_minutes_today'] as num?)?.toInt() ?? 0,
    schedule: AppSchedule.fromJson(j['schedule']),
    alwaysAllowed: j['always_allowed'] == true || j['always_allowed'] == 1,
    bonusMinutesToday: (j['bonus_minutes_today'] as num?)?.toInt() ?? 0,
    firstSeenAt: parseServerTime(j['first_seen_at']),
  );

  /// toNativeRule мантиқи зарурии model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣро иҷро мекунад.
  Map<String, dynamic> toNativeRule({
    bool bedtimeActive = false,
    bool studyActive = false,
  }) {
    if (alwaysAllowed) {
      return {
        'packageName': packageName,
        'blocked': false,
        'dailyLimitMinutes': 0,
        'schedule': null,
      };
    }
    final essential = isEssentialApp(packageName);
    final studyBlocks =
        studyActive &&
        !essential &&
        studyBlockedCategories.contains(categoryOf(this));
    return {
      'packageName': packageName,
      'blocked': blocked || (bedtimeActive && !essential) || studyBlocks,
      'dailyLimitMinutes': effectiveLimitMinutes,
      'schedule': schedule.enabled ? schedule.toJson() : null,
    };
  }
}

/// ChildLocation додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class ChildLocation {
  const ChildLocation({
    required this.latitude,
    required this.longitude,
    this.batteryLevel,
    this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final int? batteryLevel;
  final DateTime? updatedAt;

  /// Объектро аз ҷавоби JSON-и API месозад.
  static ChildLocation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lat = (raw['latitude'] as num?)?.toDouble();
    final lng = (raw['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return ChildLocation(
      latitude: lat,
      longitude: lng,
      batteryLevel: (raw['battery_level'] as num?)?.toInt(),
      updatedAt: parseServerTime(raw['updated_at']),
    );
  }

  /// Қимати online-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад.
  bool get online =>
      updatedAt != null &&
      DateTime.now().toUtc().difference(updatedAt!.toUtc()).inMinutes < 15;
}

/// FamilyChild додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class FamilyChild {
  const FamilyChild({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.paired,
    required this.pairingCode,
    required this.apps,
    this.location,
    this.parentName,
    this.bedtime = const Bedtime(),
    this.study = const StudyMode(),
    this.webFilter = const WebFilter(),
    this.childAvatar,
    this.parentAvatar,
    this.batteryLevel,
    this.unreadFromChild = 0,
    this.unreadFromParent = 0,
    this.pendingRequests = 0,
    this.lastUrgent,
  });

  final Bedtime bedtime;
  final StudyMode study;

  /// Филтри сайтҳо аз рӯи синну сол ва ҳолати охирини он дар телефони фарзанд.
  final WebFilter webFilter;

  /// Қимати childAvatar-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад.
  final String? childAvatar;
  final String? parentAvatar;

  /// Қимати batteryLevel-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад.
  final int? batteryLevel;
  final int unreadFromChild;
  final int unreadFromParent;
  final int pendingRequests;

  /// Қимати lastUrgent-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад.
  final ChatMessage? lastUrgent;

  /// Қимати ҳисобшудаи newAppsCount-ро аз ҳолати ҷорӣ бармегардонад.
  int get newAppsCount => apps.where((a) => a.isNew).length;

  final int id;
  final String name;
  final String gender;
  final int age;
  final bool paired;
  final String pairingCode;
  final List<ChildApp> apps;
  final ChildLocation? location;
  final String? parentName;

  /// Қимати ҳисобшудаи online-ро аз ҳолати ҷорӣ бармегардонад.
  bool get online => location?.online ?? false;

  /// Қимати ҳисобшудаи blockedCount-ро аз ҳолати ҷорӣ бармегардонад.
  int get blockedCount => apps.where((a) => a.blocked).length;

  /// Қимати ҳисобшудаи usageMinutesToday-ро аз ҳолати ҷорӣ бармегардонад.
  int get usageMinutesToday =>
      apps.fold(0, (sum, a) => sum + a.usageMinutesToday);

  /// FamilyChild-ро аз JSON-и сервер месозад.
  factory FamilyChild.fromJson(Map<String, dynamic> j) => FamilyChild(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? tr('Фарзанд'),
    gender: j['gender']?.toString() ?? 'boy',
    age: (j['age'] as num?)?.toInt() ?? 0,
    paired: j['is_paired'] == true || j['is_paired'] == 1,
    pairingCode: j['pairing_code']?.toString() ?? '',
    apps:
        (j['apps'] as List? ?? const [])
            .whereType<Map>()
            .map((a) => ChildApp.fromJson(Map<String, dynamic>.from(a)))
            .where((a) => a.packageName.isNotEmpty)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
    location: ChildLocation.fromJson(j['location']),
    parentName: j['parent_name']?.toString(),
    bedtime: Bedtime.fromJson(j['bedtime']),
    study: StudyMode.fromJson(j['study']),
    webFilter: WebFilter.fromJson(j['web_filter']),
    childAvatar: j['child_avatar']?.toString(),
    parentAvatar: j['parent_avatar']?.toString(),
    batteryLevel: (j['battery_level'] as num?)?.toInt(),
    unreadFromChild: (j['unread_from_child'] as num?)?.toInt() ?? 0,
    unreadFromParent: (j['unread_from_parent'] as num?)?.toInt() ?? 0,
    pendingRequests: (j['pending_requests'] as num?)?.toInt() ?? 0,
    lastUrgent: j['last_urgent'] is Map
        ? ChatMessage.fromJson(
            Map<String, dynamic>.from(j['last_urgent'] as Map),
          )
        : null,
  );
}

/// ChatMessage додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderRole,
    required this.senderName,
    required this.type,
    required this.content,
    this.createdAt,
    this.isRead = false,
  });

  /// Қимати isRead-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад.
  final bool isRead;
  final int id;
  final String senderRole;
  final String senderName;
  final String type;
  final String content;
  final DateTime? createdAt;

  /// ChatMessage-ро аз JSON-и сервер месозад.
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: (j['id'] as num).toInt(),
    senderRole: j['sender_role']?.toString() ?? '',
    senderName: j['sender_name']?.toString() ?? '',
    type: j['message_type']?.toString() ?? 'text',
    content: j['content']?.toString() ?? '',
    createdAt: parseServerTime(j['created_at']),
    isRead: j['is_read'] == true || j['is_read'] == 1,
  );
}

/// Bedtime додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class Bedtime {
  const Bedtime({
    this.enabled = false,
    this.start = '21:30',
    this.end = '07:00',
  });

  final bool enabled;
  final String start;
  final String end;

  /// Bedtime-ро аз JSON-и сервер месозад.
  factory Bedtime.fromJson(Object? raw) {
    if (raw is! Map) return const Bedtime();
    return Bedtime(
      enabled: raw['enabled'] == true,
      start: raw['start']?.toString() ?? '21:30',
      end: raw['end']?.toString() ?? '07:00',
    );
  }

  /// Объектро ба сохтори JSON барои API табдил медиҳад.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
  };

  /// activeAt мантиқи зарурии model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣро иҷро мекунад.
  bool activeAt(DateTime now) {
    if (!enabled) return false;

    /// minutes мантиқи зарурии model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣро иҷро мекунад.
    int? minutes(String hhmm) {
      final parts = hhmm.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      return h == null || m == null ? null : h * 60 + m;
    }

    final s = minutes(start);
    final e = minutes(end);
    if (s == null || e == null || s == e) return false;
    final t = now.hour * 60 + now.minute;
    return s < e ? (t >= s && t < e) : (t >= s || t < e);
  }
}

/// TimeRequest додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class TimeRequest {
  const TimeRequest({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.minutes,
    required this.status,
    this.reason,
    this.createdAt,
  });

  final int id;
  final String packageName;
  final String appName;
  final int minutes;
  final String status; // Яке аз pending, approved ё denied.
  final String? reason;
  final DateTime? createdAt;

  /// TimeRequest-ро аз JSON-и сервер месозад.
  factory TimeRequest.fromJson(Map<String, dynamic> j) => TimeRequest(
    id: (j['id'] as num).toInt(),
    packageName: j['package_name']?.toString() ?? '',
    appName: j['app_name']?.toString() ?? j['package_name']?.toString() ?? '',
    minutes: (j['requested_minutes'] as num?)?.toInt() ?? 15,
    status: j['status']?.toString() ?? 'pending',
    reason: j['reason']?.toString(),
    createdAt: parseServerTime(j['created_at']),
  );
}

/// SafePlace додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class SafePlace {
  const SafePlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  /// SafePlace-ро аз JSON-и сервер месозад.
  factory SafePlace.fromJson(Map<String, dynamic> j) => SafePlace(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    radiusMeters: (j['radius_meters'] as num?)?.toInt() ?? 150,
  );
}

/// StudyMode додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад.
class StudyMode {
  const StudyMode({
    this.enabled = false,
    this.start = '08:00',
    this.end = '13:00',
    this.weekdays = const [1, 2, 3, 4, 5, 6],
  });

  final bool enabled;
  final String start;
  final String end;
  final List<int> weekdays;

  /// StudyMode-ро аз JSON-и сервер месозад.
  factory StudyMode.fromJson(Object? raw) {
    if (raw is! Map) return const StudyMode();
    return StudyMode(
      enabled: raw['enabled'] == true,
      start: raw['start']?.toString() ?? '08:00',
      end: raw['end']?.toString() ?? '13:00',
      weekdays: (raw['weekdays'] as List? ?? const [1, 2, 3, 4, 5, 6])
          .map((d) => (d as num).toInt())
          .toList(),
    );
  }

  /// Объектро ба сохтори JSON барои API табдил медиҳад.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
    'weekdays': weekdays,
  };

  /// activeAt мантиқи зарурии model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣро иҷро мекунад.
  bool activeAt(DateTime now) {
    if (!enabled || !weekdays.contains(now.weekday)) return false;
    return Bedtime(enabled: true, start: start, end: end).activeAt(now);
  }
}

/// Филтри сайтҳо: сатҳ (off, kids — то 12 сола, teen — 13–17 сола), сайтҳое, ки волидайн
/// дастӣ бастанд, ва ҳолате, ки телефони фарзанд охирин бор хабар дод.
class WebFilter {
  const WebFilter({
    this.level = levelOff,
    this.blocked = const [],
    this.state,
    this.reportedAt,
  });

  static const levelOff = 'off';
  static const levelKids = 'kids';
  static const levelTeen = 'teen';
  static const levels = [levelOff, levelKids, levelTeen];

  /// Ҳолатҳое, ки телефони фарзанд хабар медиҳад.
  static const stateActive = 'active';
  static const stateOff = 'off';
  static const stateNeedsPermission = 'needs_permission';

  final String level;
  final List<String> blocked;
  final String? state;
  final DateTime? reportedAt;

  /// Филтр аз ҷониби волидайн фаъол карда шудааст.
  bool get enabled => level != levelOff;

  /// Сатҳи пешниҳодшуда барои синну сол: то 12 — kids, 13–17 — teen, калонтар — off.
  static String suggestedLevel(int age) {
    if (age <= 0) return levelKids;
    if (age <= 12) return levelKids;
    if (age <= 17) return levelTeen;
    return levelOff;
  }

  /// WebFilter-ро аз JSON-и сервер месозад; қимати нодуруст ба «off» табдил меёбад.
  factory WebFilter.fromJson(Object? raw) {
    if (raw is! Map) return const WebFilter();
    final level = raw['level']?.toString();
    final state = raw['state']?.toString();
    return WebFilter(
      level: levels.contains(level) ? level! : levelOff,
      blocked: (raw['blocked'] as List? ?? const [])
          .map((d) => d.toString())
          .where((d) => d.isNotEmpty)
          .toList(),
      state: state == null || state.isEmpty ? null : state,
      reportedAt: DateTime.tryParse(raw['reported_at']?.toString() ?? ''),
    );
  }

  /// Танҳо он чизе, ки волидайн мегузоранд (ҳолатро телефон хабар медиҳад).
  Map<String, dynamic> toJson() => {'level': level, 'blocked': blocked};

  /// Нусхаи нав бо сатҳ ё рӯйхати ивазшуда.
  WebFilter copyWith({String? level, List<String>? blocked}) => WebFilter(
    level: level ?? this.level,
    blocked: blocked ?? this.blocked,
    state: state,
    reportedAt: reportedAt,
  );

  /// Доменро аз суроға ҷудо мекунад: «https://www.YouTube.com/x» → «youtube.com».
  /// Агар домен нодуруст бошад, null (ҳамон қоидаҳое, ки сервер дорад).
  static String? normalizeDomain(String raw) {
    var text = raw.trim().toLowerCase();
    text = text.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
    text = text.split(RegExp(r'[/?#:]')).first;
    while (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.startsWith('www.')) text = text.substring(4);
    final labels = text.split('.');
    final label = RegExp(r'^(?!-)[a-z0-9-]{1,63}(?<!-)$');
    if (text.length > 253 || labels.length < 2) return null;
    if (!labels.every(label.hasMatch)) return null;
    if (RegExp(r'^\d+$').hasMatch(labels.last)) return null;
    return text;
  }
}
