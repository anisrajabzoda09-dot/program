import 'dart:convert';
import '../l10n/l10n.dart';

/// Pure, deterministic rules shared by the UI and the 100-point regression
/// suite. Keeping these decisions outside widgets makes the real user flows
/// testable without a Firebase connection or an Android device.
abstract final class UserJourneyLogic {
  static const limitChoices = <int>[15, 60, 90, 120, 240, 0];

  static String pairingCode(String raw) {
    final digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 6 ? digits : '';
  }

  static bool shouldOfferUpdate(int serverCode, int installedCode) =>
      serverCode > installedCode;

  static bool validPin(String value) => RegExp(r'^\d{4}$').hasMatch(value);

  static bool protectionReady(Map<String, dynamic> status) =>
      status['usage'] == true &&
      status['overlay'] == true &&
      status['accessibility'] == true;

  static int nearestLimitIndex(int minutes) {
    var best = 0;
    var distance = 1 << 30;
    for (var index = 0; index < limitChoices.length; index++) {
      final candidate = (limitChoices[index] - minutes).abs();
      if (candidate < distance) {
        distance = candidate;
        best = index;
      }
    }
    return best;
  }

  static String limitLabel(int minutes) {
    if (minutes <= 0) return tr('Бе лимит');
    if (minutes < 60) return tr('{m}д', {'m': minutes});
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0
        ? tr('{h}с', {'h': hours})
        : tr('{h}с {m}д', {'h': hours, 'm': rest});
  }

  static double usageProgress(int used, int limit) =>
      limit <= 0 ? 0 : (used / limit).clamp(0.0, 1.0).toDouble();

  static String appCategory(Map<String, dynamic> app) {
    final text = '${app['name']} ${app['packageName']}'.toLowerCase();
    if (const [
      'duolingo',
      'school',
      'academy',
      'learn',
      'khan',
    ].any(text.contains)) {
      return 'Маориф';
    }
    if (const ['roblox', 'minecraft', 'game', 'pubg'].any(text.contains)) {
      return 'Бозиҳо';
    }
    if (const [
      'telegram',
      'instagram',
      'tiktok',
      'facebook',
      'whatsapp',
    ].any(text.contains)) {
      return 'Шабакаҳо';
    }
    return 'Ҳама';
  }

  static bool appMatches(
    Map<String, dynamic> app, {
    required String query,
    required String category,
  }) {
    final needle = query.trim().toLowerCase();
    final haystack = '${app['name']} ${app['packageName']}'.toLowerCase();
    return (needle.isEmpty || haystack.contains(needle)) &&
        (category == 'Ҳама' || appCategory(app) == category);
  }

  static bool scheduleActive({
    required DateTime now,
    required String start,
    required String end,
    required Iterable<int> weekdays,
    bool enabled = true,
  }) {
    if (!enabled) return false;
    final startMinute = _minutes(start);
    final endMinute = _minutes(end);
    if (startMinute == null || endMinute == null) return false;
    final selected = weekdays.toSet();
    final current = now.hour * 60 + now.minute;
    if (startMinute <= endMinute) {
      return selected.contains(now.weekday) &&
          current >= startMinute &&
          current < endMinute;
    }
    if (current >= startMinute) return selected.contains(now.weekday);
    final previous = now.weekday == DateTime.monday
        ? DateTime.sunday
        : now.weekday - 1;
    return current < endMinute && selected.contains(previous);
  }

  static List<Map<String, dynamic>> mergeMessages(
    Iterable<Map<String, dynamic>> firebase,
    Iterable<Map<String, dynamic>> server,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    for (final item in [...server, ...firebase]) {
      final normalized = Map<String, dynamic>.from(item);
      final explicitId = normalized['id']?.toString();
      final key = explicitId != null && explicitId.isNotEmpty
          ? 'id:$explicitId'
          : [
              normalized['senderUid'] ?? normalized['senderRole'] ?? '',
              normalized['text'] ?? normalized['content'] ?? '',
              _timestamp(normalized['createdAt'] ?? normalized['created_at']),
            ].join('|');
      merged[key] = normalized;
    }
    final result = merged.values.toList();
    result.sort(
      (left, right) =>
          _timestamp(left['createdAt'] ?? left['created_at'])
              .compareTo(_timestamp(right['createdAt'] ?? right['created_at'])),
    );
    return result;
  }

  static int _timestamp(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ??
          int.tryParse(value) ??
          0;
    }
    return 0;
  }

  static int? _minutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  static String encodedAppKey(String packageName) =>
      base64Url.encode(utf8.encode(packageName)).replaceAll('=', '');
}
