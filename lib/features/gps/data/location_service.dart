import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

/// موقعیت هموارشده‌ی خودرو — چیزی که به نقشه و مارکر داده می‌شود.
class VehiclePosition {
  final double lat;
  final double lng;
  final double headingDeg; // 0-360، شمال = 0
  final double speedKmh;

  const VehiclePosition({
    required this.lat,
    required this.lng,
    required this.headingDeg,
    required this.speedKmh,
  });
}

/// استریم GPS با هموارسازی ساده (Exponential Moving Average) روی موقعیت و Heading
/// تا پرش موقعیت/چرخش خودرو نداشته باشیم.
///
/// این یک فیلتر سبک‌وزن است، نه یک Kalman Filter کامل. برای فاز بعد (Map Matching
/// واقعی روی گراف جاده‌ها که به موتور Routing/OSM نیاز دارد)، این کلاس جایگزین یا
/// تکمیل می‌شود.
class LocationService {
  final _controller = StreamController<VehiclePosition>.broadcast();
  StreamSubscription<Position>? _sub;

  double? _smoothLat;
  double? _smoothLng;
  double? _smoothHeading;

  static const double _posAlpha = 0.35; // وزن نمونه جدید برای موقعیت
  static const double _headingAlpha = 0.25; // وزن نمونه جدید برای جهت (کندتر تا نلرزد)

  Stream<VehiclePosition> get stream => _controller.stream;

  void start() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1, // متر — به‌روزرسانی حتی با حرکت کم
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
  }

  void _onPosition(Position p) {
    final rawHeading = p.heading >= 0 ? p.heading : (_smoothHeading ?? 0);

    _smoothLat = _lerp(_smoothLat, p.latitude, _posAlpha);
    _smoothLng = _lerp(_smoothLng, p.longitude, _posAlpha);
    _smoothHeading = _lerpAngle(_smoothHeading, rawHeading, _headingAlpha);

    _controller.add(VehiclePosition(
      lat: _smoothLat!,
      lng: _smoothLng!,
      headingDeg: _smoothHeading!,
      speedKmh: (p.speed.isFinite ? p.speed : 0) * 3.6,
    ));
  }

  double _lerp(double? current, double target, double alpha) {
    if (current == null) return target;
    return current + (target - current) * alpha;
  }

  /// میان‌یابی زاویه‌ای صحیح (برای این‌که چرخش از 359 به 1 درجه، یک دور کامل نچرخد)
  double _lerpAngle(double? current, double target, double alpha) {
    if (current == null) return target;
    var diff = (target - current + 540) % 360 - 180;
    return (current + diff * alpha + 360) % 360;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

double degToRad(double deg) => deg * math.pi / 180;
