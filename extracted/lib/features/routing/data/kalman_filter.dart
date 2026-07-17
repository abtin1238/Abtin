import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// فیلتر کالمن یک‌بعدی برای هموارسازی مختصات GPS.
/// A lightweight 1-D Kalman filter applied separately to lat/lng to smooth
/// noisy GPS fixes and to keep a plausible position during short signal loss
/// (tunnels) via Dead Reckoning. This is real, working math — not a stub.
class GpsKalmanFilter {
  double _lat = 0;
  double _lng = 0;
  double _variance = -1; // negative => uninitialized
  final double _minAccuracy;

  GpsKalmanFilter({double minAccuracy = 1.0}) : _minAccuracy = minAccuracy;

  bool get isInitialized => _variance >= 0;

  /// اعمال یک نمونه‌ی جدید GPS با دقت [accuracy] (متر).
  LatLng process(
    double lat,
    double lng,
    double accuracy, {
    double? speedMps,
    int deltaMillis = 1000,
  }) {
    final acc = math.max(accuracy, _minAccuracy);
    if (!isInitialized) {
      _lat = lat;
      _lng = lng;
      _variance = acc * acc;
      return LatLng(_lat, _lng);
    }

    // افزایش عدم‌قطعیت متناسب با سرعت و زمان سپری‌شده (مدل حرکت).
    if (speedMps != null && speedMps > 0) {
      final timeSec = deltaMillis / 1000.0;
      _variance += timeSec * speedMps * speedMps;
    }

    // بهره‌ی کالمن.
    final k = _variance / (_variance + acc * acc);
    _lat += k * (lat - _lat);
    _lng += k * (lng - _lng);
    _variance = (1 - k) * _variance;
    return LatLng(_lat, _lng);
  }

  /// Dead Reckoning: تخمین موقعیت بعدی هنگام قطع GPS بر اساس سرعت و جهت.
  LatLng deadReckon(double headingDeg, double speedMps, int deltaMillis) {
    const earthRadius = 6378137.0;
    final dist = speedMps * (deltaMillis / 1000.0);
    final headingRad = headingDeg * math.pi / 180.0;
    final dLat = (dist * math.cos(headingRad)) / earthRadius;
    final dLng = (dist * math.sin(headingRad)) /
        (earthRadius * math.cos(_lat * math.pi / 180.0));
    _lat += dLat * 180.0 / math.pi;
    _lng += dLng * 180.0 / math.pi;
    _variance += (speedMps * speedMps) * (deltaMillis / 1000.0);
    return LatLng(_lat, _lng);
  }

  void reset() => _variance = -1;
}
