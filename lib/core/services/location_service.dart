import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../features/routing/data/kalman_filter.dart';

/// موقعیت هموارشده به همراه سرعت و جهت حرکت.
class SmoothedPosition {
  final LatLng position;
  final double speedMps;
  final double headingDeg;
  const SmoothedPosition(this.position, this.speedMps, this.headingDeg);
}

/// سرویس موقعیت‌یابی با هموارسازی کالمن و پشتیبانی Dead Reckoning.
/// خروجی یک Stream از موقعیت‌های پایدار است که مستقیماً به نمای ناوبری
/// و موتور Map-Matching تغذیه می‌شود.
class LocationService {
  final GpsKalmanFilter _kalman = GpsKalmanFilter();
  StreamSubscription<Position>? _sub;
  final _controller = StreamController<SmoothedPosition>.broadcast();

  Stream<SmoothedPosition> get stream => _controller.stream;

  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> start() async {
    if (!await ensurePermission()) return;
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
      final smoothed = _kalman.process(
        pos.latitude,
        pos.longitude,
        pos.accuracy,
        speedMps: pos.speed,
      );
      _controller.add(
        SmoothedPosition(smoothed, pos.speed, pos.heading),
      );
    });
  }

  /// هنگام قطع GPS (تونل)، موقعیت را با Dead Reckoning تخمین بزن.
  void onSignalLost(double headingDeg, double speedMps, int deltaMillis) {
    final estimated = _kalman.deadReckon(headingDeg, speedMps, deltaMillis);
    _controller.add(SmoothedPosition(estimated, speedMps, headingDeg));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
