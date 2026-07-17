import 'package:latlong2/latlong.dart';

import '../../../core/database/app_database.dart';

/// هشدار نزدیک‌شده به کاربر.
class HazardAlert {
  final LocalHazardRow hazard;
  final double distanceMeters;
  const HazardAlert(this.hazard, this.distanceMeters);
}

/// پایش هشدارهای محلی (دوربین، مدرسه، تونل، ...) کاملاً آفلاین.
class HazardMonitor {
  HazardMonitor(this._db);
  final AppDatabase _db;
  final Distance _dist = const Distance();
  final Set<String> _recent = {};

  HazardAlert? check(LatLng position, {double maxMeters = 180}) {
    final nearby = _db.nearbyHazards(
      position.latitude,
      position.longitude,
      radiusKm: maxMeters / 1000.0 + 0.2,
    );
    HazardAlert? best;
    for (final h in nearby) {
      final d = _dist.as(
        LengthUnit.Meter,
        position,
        LatLng(h.lat, h.lon),
      );
      if (d <= (h.radiusMeters > 0 ? h.radiusMeters : maxMeters)) {
        if (_recent.contains(h.id)) continue;
        if (best == null || d < best.distanceMeters) {
          best = HazardAlert(h, d);
        }
      }
    }
    if (best != null) {
      _recent.add(best.hazard.id);
      // جلوگیری از انباشت
      if (_recent.length > 40) {
        _recent.remove(_recent.first);
      }
    }
    return best;
  }

  void reset() => _recent.clear();
}
