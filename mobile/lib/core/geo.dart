// Файл: ҳисобҳои ҷуғрофӣ — масофа байни нуқтаҳо ва муайян кардани ҷойи бехатаре, ки фарзанд дар он аст.

import 'dart:math' as math;

import 'models.dart';

/// Баромадан аз ҷой танҳо пас аз ин қадар метр берун аз радиус ҳисоб мешавад (мисли сервер),
/// то GPS дар канори ҷой «дохил/берун»-и бепоён надиҳад.
const placeLeaveMarginMeters = 40.0;

/// Нуқтаҳое, ки дақиқиашон аз ин бадтар аст, ҷойро иваз намекунанд.
const placeMaxAccuracyMeters = 150.0;

/// Масофаи байни ду нуқта бо метр (формулаи haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;

  /// Дараҷаро ба радиан табдил медиҳад.
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

/// Наздиктарин ҷойе, ки нуқта дар радиуси он аст; агар нест — null.
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

/// Ҷойи ҳозираи фарзанд бо фосилаи эҳтиётӣ: агар ӯ аллакай дар [currentId] бошад, то
/// [placeLeaveMarginMeters] берун аз радиус ҳоло ҳам дар ҳамон ҷой ҳисоб мешавад.
SafePlace? placeAt(
  double latitude,
  double longitude,
  List<SafePlace> places, {
  int? currentId,
}) {
  for (final place in places) {
    if (place.id != currentId) continue;
    final d = distanceMeters(
      latitude,
      longitude,
      place.latitude,
      place.longitude,
    );
    if (d <= place.radiusMeters + placeLeaveMarginMeters) return place;
  }
  return placeContaining(latitude, longitude, places);
}
