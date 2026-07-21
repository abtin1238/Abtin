import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';

import 'routing_service.dart';

/// مدیریت سرویس مسیریابی آفلاین با OSRM محلی
/// 
/// این سرویس سه حالت را پشتیبانی می‌کند:
/// 1. OSRM محلی (هنگام دانلود و نصب سرور محلی)
/// 2. OSRM عمومی آنلاین (fallback اگر محلی در دسترس نبود)
/// 3. مسیر خط مستقیم (fallback نهایی در حالت آفلاین کامل)
class OfflineRoutingService {
  /// URL سرور OSRM محلی (پیش‌فرض: localhost:5000)
  /// این می‌تواند توسط کاربر یا تنظیمات تغییر کند
  static String _localOsrmUrl = 'http://localhost:5000';

  /// سرور عمومی OSRM برای fallback
  static const String _publicOsrmUrl = 'https://router.project-osrm.org';

  /// timeout برای درخواست‌های HTTP
  static const Duration _httpTimeout = Duration(seconds: 15);

  /// سرویس ��سیریابی آنلاین (برای fallback)
  final RoutingService _onlineRoutingService = RoutingService();

  /// دیتای کش شده‌ی مسیرها
  final Map<String, RouteInfo> _routeCache = {};

  /// تنظیم URL سرور OSRM محلی
  /// 
  /// مثال:
  /// ```dart
  /// offlineRoutingService.setLocalOsrmUrl('http://192.168.1.100:5000');
  /// ```
  void setLocalOsrmUrl(String url) {
    _localOsrmUrl = url;
  }

  /// بررسی دسترسی به سرور OSRM محلی
  /// 
  /// این متد یک درخواست سریع به سرور محلی ارسال می‌کند.
  /// اگر پاسخ مثبت بود، سرور محلی در دسترس است.
  Future<bool> isLocalOsrmAvailable() async {
    try {
      final url = Uri.parse('$_localOsrmUrl/route/v1/driving/0,0;1,1');
      final response = await http.get(url).timeout(_httpTimeout);
      return response.statusCode == 200;
    } catch (e) {
      print('خطا در بررسی سرور محلی OSRM: $e');
      return false;
    }
  }

  /// محاسبه مسیر با ترجیح آفلاین
  /// 
  /// ترتیب سعی:
  /// 1. OSRM محلی (اگر دسترس داشته باشد)
  /// 2. OSRM عمومی آنلاین (اگر اینترنت دسترس داشته باشد)
  /// 3. خط مستقیم تقریبی (آفلاین کامل)
  Future<RouteInfo?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    bool useLocalOnly = false, // اگر true، فقط محلی رو امتحان کن
  }) async {
    try {
      // چک کنید آیا این مسیر قبلاً محاسبه شده است
      final cacheKey = _generateCacheKey(origin, destination);
      if (_routeCache.containsKey(cacheKey)) {
        print('[OSRM Offline] مسیر از کش استفاده شد');
        return _routeCache[cacheKey];
      }

      // سعی کنید از OSRM محلی استفاده کنید
      print('[OSRM Offline] تلاش برای اتصال به سرور محلی...');
      final localRoute = await _calculateRouteViaLocal(origin, destination);
      if (localRoute != null) {
        _routeCache[cacheKey] = localRoute;
        print('[OSRM Offline] مسیر از سرور محلی دریافت شد ✓');
        return localRoute;
      }

      // اگر استفاده از محلی فقط خواسته شده بود، بازگردید
      if (useLocalOnly) {
        print('[OSRM Offline] سرور محلی در دسترس نیست و استفاده از محلی الزامی است');
        return null;
      }

      // سعی کنید از OSRM عمومی استفاده کنید (آنلاین)
      print('[OSRM Offline] سرور محلی در دسترس نیست، تلاش برای استفاده از سرور عمومی...');
      final onlineRoute = await _onlineRoutingService.calculateRoute(
        origin: origin,
        destination: destination,
      );
      if (onlineRoute != null) {
        _routeCache[cacheKey] = onlineRoute;
        print('[OSRM Offline] مسیر از سرور عمومی دریافت شد (آنلاین) ⚠️');
        return onlineRoute;
      }

      // آخرین تلاش: مسیر خط مستقیم تقریبی
      print('[OSRM Offline] هیچ سرویس مسیریابی در دسترس نیست، استفاده از خط مستقیم');
      final fallbackRoute = _onlineRoutingService.straightLineFallback(origin, destination);
      _routeCache[cacheKey] = fallbackRoute;
      return fallbackRoute;
    } catch (e) {
      print('[OSRM Offline] خطا غیرمنتظره: $e');
      return null;
    }
  }

  /// محاسبه مسیر از طریق سرور OSRM محلی
  Future<RouteInfo?> _calculateRouteViaLocal(LatLng origin, LatLng destination) async {
    try {
      final url = Uri.parse(
        '$_localOsrmUrl/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true&language=fa',
      );

      final response = await http.get(url).timeout(_httpTimeout);

      if (response.statusCode != 200) {
        return null;
      }

      return _parseOsrmResponse(response.body);
    } catch (e) {
      print('[OSRM Local] خطا: $e');
      return null;
    }
  }

  /// تجزیه پاسخ OSRM
  RouteInfo? _parseOsrmResponse(String responseBody) {
    try {
      final data = json.decode(responseBody);

      if (data['code'] != 'Ok' || data['routes'] == null || data['routes'].isEmpty) {
        return null;
      }

      final route = data['routes'][0];

      // استخراج geometry
      final geometryData = route['geometry']['coordinates'] as List;
      final geometry = geometryData.map((coord) {
        return LatLng(
          (coord[1] as num).toDouble(),
          (coord[0] as num).toDouble(),
        );
      }).toList();

      // استخراج دستورات
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
            location: LatLng(
              (location[1] as num).toDouble(),
              (location[0] as num).toDouble(),
            ),
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
      print('[OSRM Parse] خطا در تجزیه پاسخ: $e');
      return null;
    }
  }

  /// تبدیل دستور انگلیسی به فارسی
  String _convertInstructionToPersian(Map<String, dynamic> step) {
    final maneuver = step['maneuver'];
    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String? ?? '';
    final name = step['name'] as String? ?? '';
    final exit = maneuver['exit'];

    if (type == 'depart') {
      return 'حرکت کنید${name.isNotEmpty ? ' در $name' : ''}';
    }
    if (type == 'arrive') {
      return name.isNotEmpty ? 'به مقصد رسیدید ($name)' : 'به مقصد رسیدید';
    }

    if (type == 'roundabout' || type == 'rotary') {
      final exitText = (exit is num) ? ' و از خروجی ${_ordinalFa(exit.toInt())} خارج شوید' : '';
      final nameText = name.isNotEmpty ? ' به $name' : '';
      return 'وارد میدان شوید$exitText$nameText'.trim();
    }

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

  /// شماره‌ی ترتیبی فارسی
  String _ordinalFa(int n) {
    const words = ['', 'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم', 'هشتم'];
    return (n >= 1 && n < words.length) ? words[n] : '$n';
  }

  /// تولید کلیدی برای کش کردن مسیرها
  String _generateCacheKey(LatLng origin, LatLng destination) {
    return '${origin.latitude},${origin.longitude}-${destination.latitude},${destination.longitude}';
  }

  /// پاک کردن کش
  void clearCache() {
    _routeCache.clear();
    print('[OSRM Offline] کش پاک شد');
  }

  /// دریافت اطلاعات آمار کش
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_routes': _routeCache.length,
      'local_osrm_url': _localOsrmUrl,
    };
  }
}

/// مدیریت دانلود داده‌های OSRM برای یک منطقه
/// 
/// این کلاس برای دانلود و مدیریت داده‌های OSRM برای استفاده آفلاین است
/// مثلاً دانلود داده‌های تهران، اصفهان و غیره
class OfflineMapDataManager {
  // می‌توان داده‌های دانلود‌شده را اینجا ذخیره کرد
  final Map<String, DownloadedMapData> _downloadedMaps = {};

  /// دانلود داده‌های مسیریابی برای منطقه‌ی مشخص
  /// 
  /// نکته: این متد فعلاً placeholder است. در عملیات حقیقی، باید:
  /// 1. داده‌های OSM (OpenStreetMap) را دانلود کنید
  /// 2. آن را به فرمت OSRM تبدیل کنید
  /// 3. بر روی دستگاه ذخیره کنید
  Future<bool> downloadMapData(String regionName, String downloadUrl) async {
    try {
      print('[OfflineMapData] شروع دانلود برای $regionName از $downloadUrl');

      // دانلود فایل
      final response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        print('[OfflineMapData] خطا: کد پاسخ ${response.statusCode}');
        return false;
      }

      // ذخیره در دستگاه
      final appDir = await getApplicationDocumentsDirectory();
      final mapDir = Directory('${appDir.path}/offline_maps/$regionName');
      if (!mapDir.existsSync()) {
        mapDir.createSync(recursive: true);
      }

      final file = File('${mapDir.path}/map_data.zip');
      await file.writeAsBytes(response.bodyBytes);

      _downloadedMaps[regionName] = DownloadedMapData(
        name: regionName,
        path: mapDir.path,
        downloadedAt: DateTime.now(),
      );

      print('[OfflineMapData] دانلود موفق برای $regionName ✓');
      return true;
    } catch (e) {
      print('[OfflineMapData] خطا در دانلود: $e');
      return false;
    }
  }

  /// دریافت فهرست نقشه‌های دانلود‌شده
  List<DownloadedMapData> getDownloadedMaps() {
    return _downloadedMaps.values.toList();
  }

  /// حذف نقشه‌ی دانلود‌شده
  Future<bool> deleteMap(String regionName) async {
    try {
      final mapData = _downloadedMaps[regionName];
      if (mapData == null) return false;

      final dir = Directory(mapData.path);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }

      _downloadedMaps.remove(regionName);
      print('[OfflineMapData] نقشه‌ی $regionName حذف شد');
      return true;
    } catch (e) {
      print('[OfflineMapData] خطا در حذف: $e');
      return false;
    }
  }
}

/// مدل برای نقشه‌های دانلود‌شده
class DownloadedMapData {
  final String name;
  final String path;
  final DateTime downloadedAt;

  DownloadedMapData({
    required this.name,
    required this.path,
    required this.downloadedAt,
  });
}
