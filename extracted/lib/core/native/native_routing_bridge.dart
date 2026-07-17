import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../features/navigation/domain/entities/route_info.dart';

/// پل MethodChannel برای موتور نیتیو GraphHopper / Valhalla.
///
/// اگر باینری نیتیو موجود نباشد، [isAvailable] = false و لایه Dart
/// (A* محلی) به‌صورت خودکار استفاده می‌شود.
class NativeRoutingBridge {
  NativeRoutingBridge({
    MethodChannel? channel,
  }) : _channel = channel ??
            const MethodChannel('ir.abtin.navigator/native_routing');

  final MethodChannel _channel;
  bool? _available;

  Future<bool> get isAvailable async {
    if (_available != null) return _available!;
    try {
      final res = await _channel.invokeMethod<bool>('isEngineReady');
      _available = res == true;
    } on MissingPluginException {
      _available = false;
    } catch (e) {
      debugPrint('NativeRoutingBridge unavailable: $e');
      _available = false;
    }
    return _available!;
  }

  /// مسیریابی با موتور نیتیو (در صورت موجود بودن).
  Future<RouteInfo?> route({
    required LatLng origin,
    required LatLng destination,
    TravelMode mode = TravelMode.car,
    RoutePreference preference = RoutePreference.fastest,
  }) async {
    if (!await isAvailable) return null;
    try {
      final raw = await _channel.invokeMethod<Map>('route', {
        'originLat': origin.latitude,
        'originLon': origin.longitude,
        'destLat': destination.latitude,
        'destLon': destination.longitude,
        'mode': mode.name,
        'preference': preference.name,
      });
      if (raw == null) return null;
      return _parse(raw, mode, preference);
    } catch (e) {
      debugPrint('Native route failed: $e');
      return null;
    }
  }

  RouteInfo? _parse(
    Map raw,
    TravelMode mode,
    RoutePreference preference,
  ) {
    final coords = (raw['coordinates'] as List?) ?? const [];
    if (coords.length < 2) return null;
    final poly = <LatLng>[];
    for (final c in coords) {
      final list = c as List;
      poly.add(LatLng((list[0] as num).toDouble(), (list[1] as num).toDouble()));
    }
    final stepsRaw = (raw['steps'] as List?) ?? const [];
    final steps = <ManeuverStep>[];
    for (final s in stepsRaw) {
      final m = Map<String, dynamic>.from(s as Map);
      final loc = (m['location'] as List?) ??
          <dynamic>[poly.first.latitude, poly.first.longitude];
      steps.add(ManeuverStep(
        instruction: (m['instruction'] as String?) ?? 'ادامه دهید',
        distanceMeters: ((m['distance'] as num?) ?? 0).toDouble(),
        type: _type((m['type'] as String?) ?? 'straight'),
        point: LatLng((loc[0] as num).toDouble(), (loc[1] as num).toDouble()),
      ));
    }
    return RouteInfo(
      polyline: poly,
      steps: steps,
      distanceMeters: ((raw['distance'] as num?) ?? 0).toDouble(),
      duration: Duration(seconds: ((raw['duration'] as num?) ?? 0).round()),
      mode: mode,
      preference: preference,
    );
  }

  ManeuverType _type(String t) {
    switch (t) {
      case 'turnRight':
        return ManeuverType.turnRight;
      case 'turnLeft':
        return ManeuverType.turnLeft;
      case 'slightRight':
        return ManeuverType.slightRight;
      case 'slightLeft':
        return ManeuverType.slightLeft;
      case 'uTurn':
        return ManeuverType.uTurn;
      case 'roundabout':
        return ManeuverType.roundabout;
      case 'arrive':
        return ManeuverType.arrive;
      case 'depart':
        return ManeuverType.depart;
      default:
        return ManeuverType.straight;
    }
  }
}
