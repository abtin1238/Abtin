import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../offline_maps/data/iran_provinces.dart';
import 'road_graph.dart';
import 'road_graph_builder.dart';

/// دانلود، ذخیره‌ی روی دیسک، و بارگذاری گراف‌های مسیریابی آفلاین — یکی به
/// ازای هر استان (همان تقسیم‌بندی [kIranProvinces] که برای دانلود تایل‌های
/// نقشه هم استفاده می‌شود، تا تجربه‌ی کاربر یکسان بماند: «دانلود استان» هم
/// نقشه هم مسیریابی آن منطقه را آفلاین می‌کند).
///
/// نکته‌ی مهم برای توسعه‌ی بعدی: سرور عمومی Overpass API
/// (overpass-api.de) برای درخواست‌های حجیم (مثل کل یک استان بزرگ) کند و
/// گاهی محدودکننده است. برای Production بهتر است یا از یک instance
/// اختصاصی Overpass استفاده شود، یا این پردازش یک‌بار روی سرور خودِ تیم
/// انجام و فایل‌های .aog آماده از یک CDN دانلود شوند (سریع‌تر و قابل‌اتکاتر
/// از پردازش لحظه‌ای Overpass روی گوشی کاربر).
class OfflineGraphStore {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  final Map<String, RoadGraph> _cache = {};

  Future<Directory> _graphsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/routing_graphs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileFor(String provinceId) async {
    final dir = await _graphsDir();
    return File('${dir.path}/$provinceId.aog');
  }

  /// آیا گراف این استان قبلاً دانلود و روی دیسک ذخیره شده؟
  Future<bool> isDownloaded(String provinceId) async {
    final f = await _fileFor(provinceId);
    return f.exists();
  }

  /// دانلود گراف مسیریابی یک استان از Overpass API و ذخیره‌ی آن به‌صورت
  /// باینری فشرده (`.aog`) روی دیسک. `onProgress` فقط دو مقدار می‌دهد (۰ و
  /// ۱) چون Overpass پیشرفت جزئی گزارش نمی‌کند — برخلاف دانلود تایل نقشه.
  Future<void> downloadProvince(
    Province province, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    final b = province.bounds;
    final query = RoadGraphBuilder.overpassQuery(
      south: b.southwest.latitude,
      west: b.southwest.longitude,
      north: b.northeast.latitude,
      east: b.northeast.longitude,
    );

    final response = await http
        .post(Uri.parse(_overpassUrl), body: {'data': query})
        .timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('خطای Overpass API: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final graph = RoadGraphBuilder.build(json);

    final file = await _fileFor(province.id);
    await file.writeAsBytes(graph.encode(), flush: true);
    _cache[province.id] = graph;
    onProgress?.call(1);
  }

  /// بارگذاری گراف یک استان در حافظه (از کش، یا از دیسک اگر قبلاً دانلود
  /// شده). اگر هنوز دانلود نشده null برمی‌گرداند.
  Future<RoadGraph?> loadProvince(String provinceId) async {
    final cached = _cache[provinceId];
    if (cached != null) return cached;

    final file = await _fileFor(provinceId);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final graph = RoadGraph.decode(bytes);
    _cache[provinceId] = graph;
    return graph;
  }

  /// پیدا کردن استانی که یک مختصات را در بر می‌گیرد (برای انتخاب خودکار
  /// گراف مناسب هنگام مسیریابی).
  Province? provinceContaining(double lat, double lng) {
    for (final p in kIranProvinces) {
      final b = p.bounds;
      if (lat >= b.southwest.latitude &&
          lat <= b.northeast.latitude &&
          lng >= b.southwest.longitude &&
          lng <= b.northeast.longitude) {
        return p;
      }
    }
    return null;
  }

  Future<void> deleteProvince(String provinceId) async {
    _cache.remove(provinceId);
    final f = await _fileFor(provinceId);
    if (await f.exists()) await f.delete();
  }
}
