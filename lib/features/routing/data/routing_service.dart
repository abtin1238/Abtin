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

  /// نکته‌ی مهم (چون امکان گرفتن لاگ از گوشی وجود ندارد): دلیل دقیق آخرین
  /// شکست مسیریابی آنلاین این‌جا نگه داشته می‌شود (کد وضعیت HTTP، بخشی از
  /// بدنه‌ی پاسخ، یا پیام Exception شبکه/تایم‌اوت) تا مستقیماً روی صفحه
  /// (در همان بنر «اتصال به سرور مسیریابی برقرار نشد») نشان داده شود، بدون
  /// نیاز به ابزار جانبی یا اتصال به کامپیوتر.
  String? lastError;

  /// محاسبه مسیر بین دو نقطه
  Future<RouteInfo?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    lastError = null;

    // نکته‌ی مهم (رفع خطای «position 127» در پاسخ OSRM): مختصاتی که از
    // هموارسازی EMA در [LocationService] بیرون می‌آیند (فایل
    // location_service.dart، متد _lerp) می‌توانند تا ۱۵-۱۶ رقم اعشار طول
    // بکشند (مثلاً ۳۵.۷۰۵۲۳۱۱۸۲۷۳۶۴۵)، چون نتیجه‌ی پی‌درپی جمع/ضرب اعشاری
    // است. نگهدارنده‌ی سرور دموی OSRM (که در این پروژه به‌عنوان _baseUrl
    // استفاده می‌شود) در بحث‌های رسمی این پروژه گفته چنین اعشارهای بلندی
    // می‌توانند در پارسر مختصات سرور مشکل ایجاد کنند و باید به دقت متعارف
    // (۶ رقم اعشار، معادل ~۱۰ سانتی‌متر که برای مسیریابی خودرو کاملاً کافی
    // است) گرد شوند. علاوه بر گرد کردن، یک لایه‌ی محافظتی هم اضافه شده تا
    // اگر (به هر دلیلی، مثلاً قطع/جهش GPS) مقدار NaN یا Infinity به این‌جا
    // برسد، به‌جای ساختن یک URL نامعتبر (که سرور آن را هم با همان خطای
    // Query malformed رد می‌کند)، همین‌جا با پیام روشن متوقف شویم.
    final originClean = _sanitizeCoordinate(origin);
    final destinationClean = _sanitizeCoordinate(destination);
    if (originClean == null || destinationClean == null) {
      lastError = 'مختصات نامعتبر (NaN/Infinity) برای مسیریابی دریافت شد';
      print('خطا در محاسبه مسیر: $lastError');
      return null;
    }

    try {
      // نکته‌ی مهم (رفع باگ اصلی «مسیریابی آنلاین همیشه HTTP 400 می‌دهد»):
      // پارامتر `language=fa` که قبلاً این‌جا اضافه شده بود، اصلاً بخشی از
      // API واقعی OSRM نیست (مخصوص سرویس‌های دیگری مثل Mapbox است). سرور
      // OSRM با دیدن این پارامتر ناشناخته، کل query string را نامعتبر
      // می‌دانست و `code: InvalidQuery` / `400 Query string malformed`
      // برمی‌گرداند — یعنی مسیریابی واقعی هیچ‌وقت موفق نمی‌شد، حتی با
      // اینترنت/سرور کاملاً سالم. ضمناً این پارامتر اصلاً لازم هم نبود،
      // چون متن فارسی دستورات همین‌جا در [_convertInstructionToPersian]
      // به‌صورت دستی از type/modifier ساخته می‌شود، نه از پاسخ سرور.
      final url = Uri.parse(
        '$_baseUrl/route/v1/driving/'
        '${originClean.longitude},${originClean.latitude};'
        '${destinationClean.longitude},${destinationClean.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http
          .get(
            url,
            headers: const {
              // نکته‌ی مهم (باگ محتمل): سیاست رسمی سرور دموی OSRM
              // (github.com/Project-OSRM/osrm-backend/wiki/Api-usage-policy)
              // صراحتاً می‌گوید هر درخواست باید یک User-Agent معتبر و
              // شناسه‌دار از اپلیکیشن داشته باشد؛ درخواست‌های بدون آن (یا با
              // User-Agent عمومی پیش‌فرض کتابخانه‌ی http که همه‌ی اپ‌های
              // Dart/Flutter مشترکاً می‌فرستند) اولین قربانی‌های
              // rate-limit/بلاک شدن پشت لایه‌ی CDN جلوی سرور هستند. قبلاً
              // این هدر اصلاً فرستاده نمی‌شد.
              'User-Agent': 'AbtinNavigator/1.0 (ir.abtin.abtin_navigator)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final bodySnippet = response.body.length > 160
            ? '${response.body.substring(0, 160)}…'
            : response.body;
        lastError = 'HTTP ${response.statusCode} از سرور مسیریابی — $bodySnippet';
        print('خطا در محاسبه مسیر: $lastError');
        return null;
      }

      final data = json.decode(response.body);

      if (data['code'] != 'Ok' || data['routes'] == null || data['routes'].isEmpty) {
        lastError = 'پاسخ سرور بدون مسیر معتبر بود (code: ${data['code']})';
        print('خطا در محاسبه مسیر: $lastError');
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
    } on TimeoutException {
      lastError = 'پاسخی از سرور مسیریابی در ۱۵ ثانیه نرسید (تایم‌اوت شبکه)';
      print('خطا در محاسبه مسیر: $lastError');
      return null;
    } catch (e) {
      lastError = 'خطای شبکه/اتصال: $e';
      print('خطا در محاسبه مسیر: $lastError');
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

  /// گرد کردن مختصات به ۶ رقم اعشار (دقت متعارف OSRM، معادل ~۱۰ سانتی‌متر)
  /// + رد کردن مقادیر نامعتبر (NaN/Infinity) که ممکن است از هموارسازی EMA
  /// موقعیت (location_service.dart) یا از GPS خام برسند. اگر مقدار نامعتبر
  /// باشد null برمی‌گرداند تا فراخواننده به‌جای ساختن URL خراب، همان‌جا
  /// متوقف شود.
  LatLng? _sanitizeCoordinate(LatLng coord) {
    final lat = coord.latitude;
    final lng = coord.longitude;
    if (lat.isNaN || lat.isInfinite || lng.isNaN || lng.isInfinite) {
      return null;
    }
    double round6(double v) => (v * 1000000).round() / 1000000;
    return LatLng(round6(lat), round6(lng));
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
