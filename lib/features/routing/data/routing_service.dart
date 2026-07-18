import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

/// مدل اطلاعات مسیر محاسبه‌شده
class RouteInfo {
  final List<LatLng> geometry; // نقاط مسیر برای ترسیم Polyline
  final double distanceKm; // مسافت کل به کیلومتر
  final double durationMin; // زمان تقریبی به دقیقه
  final List<RouteInstruction> instructions; // دستورات پیچ‌به‌پیچ

  const RouteInfo({
    required this.geometry,
    required this.distanceKm,
    required this.durationMin,
    required this.instructions,
  });
}

/// یک دستور مسیریابی (مثلاً "بعد از ۲۰۰ متر به راست بپیچید")
class RouteInstruction {
  final String text; // متن دستور
  final double distanceMeters; // فاصله تا این دستور
  final LatLng location; // موقعیت این دستور
  final String type; // نوع دستور: turn, arrive, depart, etc.

  const RouteInstruction({
    required this.text,
    required this.distanceMeters,
    required this.location,
    required this.type,
  });
}

/// سرویس مسیریابی با استفاده از OSRM API (رایگان و عمومی)
/// 
/// نکته: برای استفاده‌ی حرفه‌ای، می‌توانید سرور OSRM یا Valhalla خودتان را راه‌اندازی کنید
/// یا از سرویس‌های پولی مثل MapBox Directions استفاده کنید.
class RoutingService {
  // سرور عمومی OSRM - برای تست مناسب است، برای Production باید سرور اختصاصی استفاده کنید
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// محاسبه مسیر بین دو نقطه
  Future<RouteInfo?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true&language=fa',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      
      if (data['code'] != 'Ok' || data['routes'] == null || data['routes'].isEmpty) {
        return null;
      }

      final route = data['routes'][0];
      
      // استخراج geometry مسیر
      final geometryData = route['geometry']['coordinates'] as List;
      final geometry = geometryData.map((coord) {
        return LatLng(coord[1] as double, coord[0] as double);
      }).toList();

      // استخراج دستورات مسیریابی
      final instructions = <RouteInstruction>[];
      final legs = route['legs'] as List;
      
      for (var leg in legs) {
        final steps = leg['steps'] as List;
        for (var step in steps) {
          final maneuver = step['maneuver'];
          final location = maneuver['location'];
          
          instructions.add(RouteInstruction(
            text: _convertInstructionToPersian(step),
            distanceMeters: (step['distance'] as num).toDouble(),
            location: LatLng(location[1] as double, location[0] as double),
            type: maneuver['type'] as String? ?? 'turn',
          ));
        }
      }

      return RouteInfo(
        geometry: geometry,
        distanceKm: (route['distance'] as num).toDouble() / 1000,
        durationMin: (route['duration'] as num).toDouble() / 60,
        instructions: instructions,
      );
    } catch (e) {
      print('خطا در محاسبه مسیر: $e');
      return null;
    }
  }

  /// تبدیل دستور انگلیسی OSRM به فارسی
  String _convertInstructionToPersian(Map<String, dynamic> step) {
    final maneuver = step['maneuver'];
    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String? ?? '';
    final distance = (step['distance'] as num).toDouble();
    final name = step['name'] as String? ?? '';

    // دستورات پایه
    if (type == 'depart') {
      return 'حرکت کنید${name.isNotEmpty ? ' در $name' : ''}';
    }
    
    if (type == 'arrive') {
      return 'به مقصد رسیدید';
    }

    // پیچ‌ها
    String direction = '';
    if (modifier.contains('right')) {
      direction = 'راست';
    } else if (modifier.contains('left')) {
      direction = 'چپ';
    } else if (modifier.contains('straight')) {
      direction = 'مستقیم';
    } else if (modifier.contains('slight right')) {
      direction = 'کمی به راست';
    } else if (modifier.contains('slight left')) {
      direction = 'کمی به چپ';
    } else if (modifier.contains('sharp right')) {
      direction = 'کاملاً به راست';
    } else if (modifier.contains('sharp left')) {
      direction = 'کاملاً به چپ';
    } else if (modifier.contains('uturn')) {
      direction = 'دور بزنید';
    }

    String action = '';
    if (type == 'turn') {
      action = 'بپیچید';
    } else if (type == 'new name') {
      action = 'ادامه دهید';
    } else if (type == 'continue') {
      action = 'ادامه دهید';
    } else if (type == 'merge') {
      action = 'ادغام شوید';
    } else if (type == 'on ramp' || type == 'off ramp') {
      action = 'وارد شوید';
    } else if (type == 'fork') {
      action = 'انتخاب کنید';
    } else if (type == 'roundabout' || type == 'rotary') {
      action = 'وارد میدان شوید';
    }

    String distanceText = '';
    if (distance > 1000) {
      distanceText = 'بعد از ${(distance / 1000).toStringAsFixed(1)} کیلومتر';
    } else if (distance > 100) {
      distanceText = 'بعد از ${distance.round()} متر';
    } else if (distance > 0) {
      distanceText = 'بعد از ${distance.round()} متر';
    }

    final nameText = name.isNotEmpty ? ' به $name' : '';
    
    return '$distanceText $action $direction$nameText'.trim();
  }
}
