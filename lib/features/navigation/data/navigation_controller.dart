import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/bootstrap.dart';
import '../../../core/database/app_database.dart';
import '../../../core/platform/car_projection.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/services/tts_service.dart';
import '../../voice/data/offline_voice_guide.dart';
import '../domain/entities/nav_state.dart';
import '../domain/entities/route_info.dart';
import 'hazard_monitor.dart';

/// نقطهٔ شروع پیش‌فرض (مرکز شهر نمونه) وقتی GPS هنوز آماده نیست.
const LatLng _defaultStart = LatLng(35.7219, 51.4056);

/// کنترلر زندهٔ ناوبری — آفلاین کامل.
///
/// - Turn-by-turn + ETA + سرعت
/// - Reroute آفلاین هنگام انحراف
/// - هشدار محلی (دوربین/مدرسه/تونل)
/// - راهنمای صوتی
/// - پخش مانور به Android Auto / CarPlay
class NavigationController extends StateNotifier<NavigationState> {
  NavigationController({
    RoutingService? routing,
    AppDatabase? database,
    TtsService? tts,
    CarProjectionService? car,
  })  : _routing = routing,
        _db = database,
        _tts = tts ?? TtsService(),
        _car = car ?? CarProjectionService(),
        super(const NavigationState(
          isNavigating: false,
          position: _defaultStart,
          headingDeg: 0,
          currentSpeedKmh: 0,
        )) {
    if (_db != null) {
      _hazards = HazardMonitor(_db!);
    }
    _voice = OfflineVoiceGuide(_tts);
  }

  final RoutingService? _routing;
  final AppDatabase? _db;
  final TtsService _tts;
  final CarProjectionService _car;
  late final OfflineVoiceGuide _voice;
  HazardMonitor? _hazards;

  final LocationService _location = LocationService();
  StreamSubscription<SmoothedPosition>? _locSub;
  Timer? _followTimer;
  Timer? _gpsWatchdog;

  RouteInfo? _route;
  List<double> _cum = const [];
  List<double> _maneuverAlong = const [];
  double _traveled = 0;
  double _speed = 0;
  DateTime? _lastGpsAt;
  bool _rerouting = false;
  int _currentStepIndex = 0;

  final Distance _dist = const Distance();

  LatLng get safePosition => state.position ?? _defaultStart;

  Future<void> start() async {
    _locSub = _location.stream.listen(_onGpsSample);
    try {
      await _location.start();
      await _tts.init();
      await _car.registerAsNavigationApp();
    } catch (_) {}
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      final last = _lastGpsAt;
      if (last == null) return;
      final gap = DateTime.now().difference(last);
      if (gap.inSeconds >= 3) {
        // Dead Reckoning هنگام قطع GPS
        _location.onSignalLost(
          state.headingDeg,
          state.currentSpeedKmh / 3.6,
          gap.inMilliseconds,
        );
      }
    });
  }

  void _onGpsSample(SmoothedPosition s) {
    _lastGpsAt = DateTime.now();
    if (!state.isNavigating) {
      state = state.copyWith(
        position: s.position,
        headingDeg: s.headingDeg,
        currentSpeedKmh: (s.speedMps * 3.6).clamp(0, 400).toDouble(),
      );
      return;
    }

    // در حین ناوبری: map-match نرم + بررسی انحراف
    final route = _route;
    if (route == null || route.polyline.length < 2) return;

    final nearest = _nearestOnRoute(s.position);
    final offRoute = nearest.distance > 45;
    if (offRoute) {
      unawaited(_tryReroute(s.position));
    }

    // همگام‌سازی موقعیت شبیه‌سازی با GPS واقعی در صورت نزدیک بودن
    if (!offRoute && nearest.distance < 25) {
      _traveled = nearest.along;
    }

    _checkHazards(s.position, s.speedMps * 3.6);
  }

  Future<void> _tryReroute(LatLng current) async {
    if (_rerouting || _routing == null) return;
    final dest = state.destination;
    if (dest == null) return;
    _rerouting = true;
    try {
      final next = await _routing!.reroute(
        current: current,
        destination: dest,
        mode: _route?.mode ?? TravelMode.car,
        preference: _route?.preference ?? RoutePreference.fastest,
      );
      if (next != null && next.polyline.length >= 2) {
        await _voice.announceHazard('تغییر مسیر');
        startRoute(next);
      }
    } finally {
      _rerouting = false;
    }
  }

  void _checkHazards(LatLng pos, double speedKmh) {
    final mon = _hazards;
    if (mon == null) return;
    final alert = mon.check(pos);
    if (alert == null) return;
    unawaited(_voice.announceHazard(alert.hazard.title));
    if (alert.hazard.speedLimit != null) {
      state = state.copyWith(speedLimitKmh: alert.hazard.speedLimit);
    }
  }

  /// آغاز ناوبری با مسیر محاسبه‌شده (آفلاین A* یا نیتیو).
  bool startRoute(RouteInfo route) {
    if (route.polyline.length < 2) return false;

    _route = route;
    _buildMetrics(route);
    _traveled = 0;
    _speed = 0;
    _currentStepIndex = 0;
    _hazards?.reset();

    final firstManeuver = route.steps.isNotEmpty ? route.steps.first : null;
    state = state.copyWith(
      isNavigating: true,
      destination: route.polyline.last,
      routePolyline: route.polyline,
      position: route.polyline.first,
      headingDeg: _bearing(route.polyline[0], route.polyline[1]),
      currentSpeedKmh: 0,
      speedLimitKmh: 60,
      nextManeuver: firstManeuver,
      distanceToManeuverMeters:
          _maneuverAlong.isNotEmpty ? _maneuverAlong.first : 0,
      remainingDistanceMeters: route.distanceMeters,
      remainingTime: route.duration,
      eta: DateTime.now().add(route.duration),
    );

    unawaited(_voice.start());
    _startFollow();
    _pushCarManeuver();
    return true;
  }

  void stopNavigation() {
    _followTimer?.cancel();
    _followTimer = null;
    _route = null;
    unawaited(_voice.stop());
    state = state.copyWith(
      isNavigating: false,
      clearDestination: true,
      routePolyline: const [],
      currentSpeedKmh: 0,
    );
  }

  void _buildMetrics(RouteInfo route) {
    final poly = route.polyline;
    final cum = List<double>.filled(poly.length, 0);
    for (var i = 1; i < poly.length; i++) {
      cum[i] = cum[i - 1] + _dist.as(LengthUnit.Meter, poly[i - 1], poly[i]);
    }
    _cum = cum;

    final along = <double>[];
    for (final step in route.steps) {
      var best = double.infinity;
      var bestIdx = 0;
      for (var i = 0; i < poly.length; i++) {
        final d = _dist.as(LengthUnit.Meter, poly[i], step.point);
        if (d < best) {
          best = d;
          bestIdx = i;
        }
      }
      along.add(cum[bestIdx]);
    }
    _maneuverAlong = along;
  }

  void _startFollow() {
    _followTimer?.cancel();
    const tick = Duration(milliseconds: 120);
    const dt = 0.12;
    _followTimer = Timer.periodic(tick, (_) {
      final route = _route;
      if (route == null || _cum.isEmpty) return;
      final total = _cum.last;

      double dtn = double.infinity;
      ManeuverStep? nextManeuver = state.nextManeuver;
      var stepIdx = _currentStepIndex;
      for (var i = 0; i < _maneuverAlong.length; i++) {
        final ahead = _maneuverAlong[i] - _traveled;
        if (ahead >= -5) {
          dtn = ahead < 0 ? 0 : ahead;
          nextManeuver = route.steps[i];
          stepIdx = i;
          break;
        }
      }
      _currentStepIndex = stepIdx;

      double target;
      final arrived = _traveled >= total - 0.5;
      if (arrived) {
        target = 0;
      } else if (dtn < 35) {
        target = 20;
      } else if (dtn < 90) {
        target = 34;
      } else {
        target = 60 + math.sin(DateTime.now().millisecondsSinceEpoch / 1500) * 4;
      }

      _speed += (target - _speed) * 0.18;
      if (arrived && _speed < 0.4) _speed = 0.0;

      _traveled += (_speed / 3.6) * dt;
      if (_traveled > total) _traveled = total;

      final pos = _pointAt(_traveled);
      final hd = _headingAt(_traveled);
      final remaining = math.max(0.0, total - _traveled);
      final remTime = _speed > 3
          ? Duration(seconds: (remaining / (_speed / 3.6)).round())
          : state.remainingTime;

      state = state.copyWith(
        position: pos,
        headingDeg: hd,
        currentSpeedKmh: _speed,
        speedLimitKmh: state.speedLimitKmh ?? 60,
        nextManeuver: arrived
            ? (route.steps.isNotEmpty ? route.steps.last : nextManeuver)
            : nextManeuver,
        distanceToManeuverMeters: dtn.isFinite ? dtn : 0,
        remainingDistanceMeters: remaining,
        remainingTime: remTime,
        eta: DateTime.now().add(remTime),
      );

      unawaited(_voice.onNavigationTick(
        steps: route.steps,
        currentStepIndex: stepIdx,
        distanceToNextMeters: dtn.isFinite ? dtn : 0,
        speedKmh: _speed,
        speedLimit: state.speedLimitKmh,
      ));

      if (stepIdx != _currentStepIndex) {
        _pushCarManeuver();
      }

      if (arrived && _speed < 1.2) {
        _speed = 0;
        _followTimer?.cancel();
        _followTimer = null;
        unawaited(_tts.speak('به مقصد رسیدید'));
      }
    });
  }

  void _pushCarManeuver() {
    final m = state.nextManeuver;
    if (m == null) return;
    unawaited(_car.pushManeuver(
      instruction: m.instruction,
      distanceMeters: state.distanceToManeuverMeters,
      remainingMeters: state.remainingDistanceMeters,
      etaEpochMs: (state.eta ?? DateTime.now()).millisecondsSinceEpoch,
    ));
  }

  ({double along, double distance}) _nearestOnRoute(LatLng p) {
    final poly = _route?.polyline ?? const <LatLng>[];
    if (poly.isEmpty) return (along: 0, distance: double.infinity);
    var bestD = double.infinity;
    var bestAlong = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final d = _dist.as(LengthUnit.Meter, p, poly[i]);
      if (d < bestD) {
        bestD = d;
        bestAlong = i < _cum.length ? _cum[i] : 0;
      }
    }
    return (along: bestAlong, distance: bestD);
  }

  LatLng _pointAt(double s) {
    final poly = _route!.polyline;
    if (s <= 0) return poly.first;
    if (s >= _cum.last) return poly.last;
    var i = 0;
    while (i < _cum.length - 1 && _cum[i + 1] < s) {
      i++;
    }
    final segLen = _cum[i + 1] - _cum[i];
    final t = segLen <= 0 ? 0.0 : (s - _cum[i]) / segLen;
    final a = poly[i], b = poly[i + 1];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  double _headingAt(double s) {
    final poly = _route!.polyline;
    var i = 0;
    while (i < _cum.length - 1 && _cum[i + 1] < s) {
      i++;
    }
    if (i >= poly.length - 1) return state.headingDeg;
    return _bearing(poly[i], poly[i + 1]);
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitudeInRad, lat2 = b.latitudeInRad;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _followTimer?.cancel();
    _gpsWatchdog?.cancel();
    _location.dispose();
    super.dispose();
  }
}

/// Provider سراسری وضعیت ناوبری زنده.
final navigationControllerProvider =
    StateNotifierProvider<NavigationController, NavigationState>((ref) {
  RoutingService? routing;
  AppDatabase? db;
  try {
    routing = ref.watch(routingServiceProvider);
  } catch (_) {}
  try {
    db = ref.watch(appDatabaseProvider);
  } catch (_) {}
  // import routingServiceProvider via app_providers — resolved at runtime
  return NavigationController(routing: routing, database: db)..start();
});
