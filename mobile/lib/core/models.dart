import '../ui/widgets.dart' show parseServerTime;
import 'app_categories.dart';
import '../l10n/l10n.dart';

/// Typed views over the server snapshot JSON (see app/routers/mobile.py
/// `_mobile_child_payload`).

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

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
    'weekdays': weekdays,
  };
}

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

  /// Daily limit including today's bonus (0 = no limit).
  int get effectiveLimitMinutes =>
      dailyLimitMinutes == 0 ? 0 : dailyLimitMinutes + bonusMinutesToday;

  /// Installed within the last 24 hours.
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

  /// Rule sent to the native blocker (`setAppControlRules`). The native
  /// side is unchanged; bonus time, «always allowed», bedtime and study mode
  /// only adjust what is sent. Phone/SMS/system essentials are never forced
  /// closed by bedtime or study mode, so the child can always call.
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

  /// Online = location reported within the last 15 minutes.
  bool get online =>
      updatedAt != null &&
      DateTime.now().toUtc().difference(updatedAt!.toUtc()).inMinutes < 15;
}

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

  /// Server paths of profile photos (use NigohApi.fileUrl), null if none.
  final String? childAvatar;
  final String? parentAvatar;

  /// Last reported battery % of the child's phone (null if unknown).
  final int? batteryLevel;
  final int unreadFromChild;
  final int unreadFromParent;
  final int pendingRequests;

  /// Unread SOS from the child within the last 24 h (parent shows an alert).
  final ChatMessage? lastUrgent;
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

  bool get online => location?.online ?? false;
  int get blockedCount => apps.where((a) => a.blocked).length;
  int get usageMinutesToday =>
      apps.fold(0, (sum, a) => sum + a.usageMinutesToday);

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

  /// The other side has opened the chat since this was sent.
  final bool isRead;
  final int id;
  final String senderRole;
  final String senderName;
  final String type;
  final String content;
  final DateTime? createdAt;

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

/// Phone-wide quiet hours: every app except «always allowed» ones is blocked.
class Bedtime {
  const Bedtime({
    this.enabled = false,
    this.start = '21:30',
    this.end = '07:00',
  });

  final bool enabled;
  final String start;
  final String end;

  factory Bedtime.fromJson(Object? raw) {
    if (raw is! Map) return const Bedtime();
    return Bedtime(
      enabled: raw['enabled'] == true,
      start: raw['start']?.toString() ?? '21:30',
      end: raw['end']?.toString() ?? '07:00',
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
  };

  /// True when [now] is inside the window (handles windows over midnight).
  bool activeAt(DateTime now) {
    if (!enabled) return false;
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
  final String status; // pending | approved | denied
  final String? reason;
  final DateTime? createdAt;

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

  factory SafePlace.fromJson(Map<String, dynamic> j) => SafePlace(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    radiusMeters: (j['radius_meters'] as num?)?.toInt() ?? 150,
  );
}

/// «Тамаркузи дарс»: during school hours games, social and video apps are
/// blocked; education, essentials (phone, SMS) and «always allowed» stay open.
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

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
    'weekdays': weekdays,
  };

  bool activeAt(DateTime now) {
    if (!enabled || !weekdays.contains(now.weekday)) return false;
    return Bedtime(enabled: true, start: start, end: end).activeAt(now);
  }
}
