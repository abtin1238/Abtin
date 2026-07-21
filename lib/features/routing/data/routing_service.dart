import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      
      if (data['code'] != 'Ok' || data['routes'] == null || data['routes'].isEmpty) {
        return null;
      }

      final route = data['routes'][0];
      
      // استخراج geometry مسیر
      // نکته‌ی مهم (رفع باگ «مسیریابی آنلاین همیشه به مسیر تقریبی سقوط
      // می‌کند»): مقادیر مختصات از JSON وقتی عدد صحیح باشند (مثلاً یک طول
      // جغرافیایی دقیقاً روی X.0) به‌صورت int دیکد می‌شوند نه double؛ کست
      // مستقیم `as double` روی چنین مقداری Exception می‌دهد که همین‌جا در
      // catch پایین بی‌صدا قورت داده می‌شد و کل تابع null برمی‌گرداند —
      // یعنی مسیریابی واقعی هرگز موفق نمی‌شد و همیشه به خط مستقیم تقریبی
      // سقوط می‌کرد، حتی با اینترنت و سرور کاملاً سالم. `(x as num).toDouble()`
      // هم int و هم double را درست تبدیل می‌کند.
      final geometryData = route['geometry']['coordinates'] as List;
      final geometry = geometryData.map((coord) {
        return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
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
            location: LatLng((location[1] as num).toDouble(), (location[0] as num).toDouble()),
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

  /// مسیر جایگزینِ ساده (خط مستقیم) — وقتی اینترنت/سرور OSRM در دسترس نیست
  /// (حالت آفلاین). فقط جهت کلی به سمت مقصد را می‌دهد، نه مسیر واقعی جاده‌ها.
  RouteInfo straightLineFallback(LatLng origin, LatLng destination) {
    final distanceM = _haversine(origin, destination);
    return RouteInfo(
      geometry: [origin, destination],
      distanceKm: distanceM / 1000,
      durationMin: (distanceM / 1000) / 45 * 60, // فرض سرعت میانگین ۴۵ km/h
      instructions: [
        RouteInstruction(
          text: 'به سمت مقصد حرکت کنید (مسیر آفلاین تقریبی)',
          distanceMeters: distanceM,
          location: origin,
          type: 'depart',
        ),
        RouteInstruction(
          text: 'به مقصد رسیدید',
          distanceMeters: 0,
          location: destination,
          type: 'arrive',
        ),
      ],
    );
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  /// تبدیل دستور انگلیسی OSRM به فارسی
  String _convertInstructionToPersian(Map<String, dynamic> step) {
    final maneuver = step['maneuver'];
    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String? ?? '';
    final name = step['name'] as String? ?? '';
    final exit = maneuver['exit'];

    // دستورات پایه
    if (type == 'depart') {
      return 'حرکت کنید${name.isNotEmpty ? ' در $name' : ''}';
    }
    if (type == 'arrive') {
      return name.isNotEmpty ? 'به مقصد رسیدید ($name)' : 'به مقصد رسیدید';
    }

    // میدان‌ها: خروجی چندم را هم بگو
    if (type == 'roundabout' || type == 'rotary') {
      final exitText = (exit is num) ? ' و از خروجی ${_ordinalFa(exit.toInt())} خارج شوید' : '';
      final nameText = name.isNotEmpty ? ' به $name' : '';
      return 'وارد میدان شوید$exitText$nameText'.trim();
    }

    // جهت پیچ — مهم: حالت‌های sharp/slight را قبل از حالت ساده بررسی کن
    String direction = '';
    if (modifier.contains('sharp right')) {
      direction = 'کاملاً به راست';
    } else if (modifier.contains('sharp left')) {
      direction = 'کاملاً به چپ';
    } else if (modifier.contains('slight right')) {
      direction = 'کمی به راست';
    } else if (modifier.contains('slight left')) {
      direction = 'کمی به چپ';
    } else if (modifier.contains('uturn')) {
      direction = 'دور بزنید';
    } else if (modifier.contains('right')) {
      direction = 'به راست';
    } else if (modifier.contains('left')) {
      direction = 'به چپ';
    } else if (modifier.contains('straight')) {
      direction = 'مستقیم';
    }

    String action = '';
    if (type == 'turn') {
      action = 'بپیچید';
    } else if (type == 'new name' || type == 'continue') {
      action = 'ادامه دهید';
    } else if (type == 'merge') {
      action = 'ادغام شوید';
    } else if (type == 'on ramp' || type == 'off ramp') {
      action = 'وارد شوید';
    } else if (type == 'fork') {
      action = 'مسیر را انتخاب کنید';
    } else if (type == 'end of road') {
      action = 'در انتهای خیابان بپیچید';
    }
    if (action.isEmpty) action = 'ادامه دهید';

    final nameText = name.isNotEmpty ? ' به $name' : '';
    return '$action $direction$nameText'.trim();
  }

  /// شماره‌ی ترتیبی فارسی برای خروجی میدان
  String _ordinalFa(int n) {
    const words = ['', 'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم', 'هشتم'];
    return (n >= 1 && n < words.length) ? words[n] : '$n';
  }
}
