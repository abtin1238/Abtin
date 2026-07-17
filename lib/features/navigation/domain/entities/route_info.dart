import 'package:latlong2/latlong.dart';

/// نوع وسیله‌ی نقلیه برای مسیریابی چندحالته.
enum TravelMode { car, truck, motorcycle, bicycle, pedestrian }

/// معیار انتخاب مسیر.
enum RoutePreference { fastest, shortest, economic }

/// یک دستور مانور (پیچ به راست/چپ، ادامه مسیر، ...).
class ManeuverStep {
  final String instruction;
  final double distanceMeters;
  final ManeuverType type;
  final LatLng point;

  const ManeuverStep({
    required this.instruction,
    required this.distanceMeters,
    required this.type,
    required this.point,
  });
}

enum ManeuverType {
  turnRight,
  turnLeft,
  slightRight,
  slightLeft,
  straight,
  uTurn,
  roundabout,
  arrive,
  depart,
}

/// موجودیت مسیر محاسبه‌شده توسط موتور آفلاین.
class RouteInfo {
  final List<LatLng> polyline;
  final List<ManeuverStep> steps;
  final double distanceMeters;
  final Duration duration;
  final TravelMode mode;
  final RoutePreference preference;

  const RouteInfo({
    required this.polyline,
    required this.steps,
    required this.distanceMeters,
    required this.duration,
    required this.mode,
    required this.preference,
  });

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} کیلومتر';
    }
    return '${distanceMeters.toStringAsFixed(0)} متر';
  }

  String get durationLabel {
    final m = duration.inMinutes;
    if (m >= 60) return '${m ~/ 60} ساعت و ${m % 60} دقیقه';
    return '$m دقیقه';
  }
}
