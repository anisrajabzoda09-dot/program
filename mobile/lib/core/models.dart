import '../ui/widgets.dart' show parseServerTime;

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
  });

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
  );

  /// Rule list sent to the native blocker (`setAppControlRules`).
  Map<String, dynamic> toNativeRule() => {
    'packageName': packageName,
    'blocked': blocked,
    'dailyLimitMinutes': dailyLimitMinutes,
    'schedule': schedule.enabled ? schedule.toJson() : null,
  };
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
  });

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
    name: j['name']?.toString() ?? 'Фарзанд',
    gender: j['gender']?.toString() ?? 'boy',
    age: (j['age'] as num?)?.toInt() ?? 0,
    paired: j['is_paired'] == true || j['is_paired'] == 1,
    pairingCode: j['pairing_code']?.toString() ?? '',
    apps: (j['apps'] as List? ?? const [])
        .whereType<Map>()
        .map((a) => ChildApp.fromJson(Map<String, dynamic>.from(a)))
        .where((a) => a.packageName.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    location: ChildLocation.fromJson(j['location']),
    parentName: j['parent_name']?.toString(),
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
  });

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
  );
}
