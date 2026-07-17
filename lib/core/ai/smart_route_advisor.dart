import 'package:latlong2/latlong.dart';

import '../../features/navigation/domain/entities/route_info.dart';

/// پیشنهاد مسیر هوشمند کاملاً آفلاین (بدون شبکه).
///
/// بر اساس ساعت روز، تاریخچه ترجیحات کاربر و نوع وسیله،
/// preference و mode پیشنهادی را برمی‌گرداند.
class SmartRouteAdvisor {
  const SmartRouteAdvisor();

  /// پیش‌بینی زمان سفر با ضریب ترافیک محلی تقریبی.
  Duration predictTravelTime({
    required double distanceMeters,
    required TravelMode mode,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final hour = t.hour;
    // ضریب ترافیک تقریبی تهران (آفلاین)
    double traffic = 1.0;
    if (hour >= 7 && hour <= 9) traffic = 1.45;
    if (hour >= 16 && hour <= 19) traffic = 1.55;
    if (hour >= 12 && hour <= 14) traffic = 1.15;
    if (hour >= 22 || hour <= 5) traffic = 0.85;

    final baseKmh = switch (mode) {
      TravelMode.car => 38.0,
      TravelMode.truck => 30.0,
      TravelMode.motorcycle => 42.0,
      TravelMode.bicycle => 16.0,
      TravelMode.pedestrian => 4.8,
    };
    final hours = (distanceMeters / 1000.0) / (baseKmh / traffic);
    return Duration(seconds: (hours * 3600).round().clamp(60, 24 * 3600));
  }

  /// پیشنهاد preference بر اساس الگوهای کاربر.
  RoutePreference suggestPreference({
    required List<RoutePreference> recentChoices,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    if (recentChoices.length >= 3) {
      final counts = <RoutePreference, int>{};
      for (final c in recentChoices) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.first.key;
    }
    // صبح: سریع‌ترین، شب: اقتصادی
    if (t.hour >= 7 && t.hour <= 10) return RoutePreference.fastest;
    if (t.hour >= 21 || t.hour <= 6) return RoutePreference.economic;
    return RoutePreference.shortest;
  }

  /// مسیرهای محبوب کاربر (بر اساس تکرار مبدأ/مقصد).
  List<String> rememberRouteKeys({
    required LatLng origin,
    required LatLng destination,
  }) {
    String key(LatLng p) =>
        '${p.latitude.toStringAsFixed(3)},${p.longitude.toStringAsFixed(3)}';
    return ['${key(origin)}→${key(destination)}'];
  }

  /// پیشنهاد زمان حرکت برای اجتناب از اوج ترافیک.
  DateTime suggestDeparture(DateTime desiredArrival, double distanceMeters) {
    final est = predictTravelTime(
      distanceMeters: distanceMeters,
      mode: TravelMode.car,
      now: desiredArrival.subtract(const Duration(hours: 1)),
    );
    var dep = desiredArrival.subtract(est + const Duration(minutes: 15));
    // اگر در اوج است، ۱۵ دقیقه زودتر
    if (dep.hour >= 7 && dep.hour <= 9 || dep.hour >= 16 && dep.hour <= 19) {
      dep = dep.subtract(const Duration(minutes: 20));
    }
    return dep;
  }
}
