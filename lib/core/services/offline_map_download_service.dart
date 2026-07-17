import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

/// یک منطقهٔ قابل دانلود برای استفادهٔ آفلاین (کشور / استان).
class DownloadableRegion {
  final String id;
  final String name;
  final LatLngBounds bounds;
  /// سطح: country | province
  final String level;
  /// برای استان‌ها: شناسهٔ کشور والد
  final String? parentId;
  /// اندازهٔ تقریبی برای UI (MB) — تخمینی
  final double approxSizeMb;

  DownloadableRegion(
    this.id,
    this.name,
    this.bounds, {
    this.level = 'country',
    this.parentId,
    this.approxSizeMb = 50,
  });
}

/// فهرست مناطق قابل دانلود.
///
/// - کشورهای همسایه (کل‌نگر)
/// - **استان‌های ایران** (دانلود جداگانه برای حجم کمتر و آفلاین هدفمند)
///
/// توجه: این لایه **کاشی نقشه** را دانلود می‌کند.
/// مسیریابی دقیق آفلاین نیاز به **گراف جاده** همان منطقه دارد
/// (نمونه تهران bundled است؛ برای کل ایران باید بستهٔ graph/OSM نصب شود).
final List<DownloadableRegion> downloadableRegions = [
  // ---- کشورها ----
  DownloadableRegion(
    'iran',
    'ایران (کل کشور)',
    LatLngBounds(const LatLng(25.0, 44.0), const LatLng(39.8, 63.4)),
    level: 'country',
    approxSizeMb: 1200,
  ),
  DownloadableRegion(
    'turkey',
    'ترکیه',
    LatLngBounds(const LatLng(35.8, 25.6), const LatLng(42.2, 44.8)),
    level: 'country',
    approxSizeMb: 800,
  ),
  DownloadableRegion(
    'uae',
    'امارات متحده عربی',
    LatLngBounds(const LatLng(22.5, 51.4), const LatLng(26.1, 56.4)),
    level: 'country',
    approxSizeMb: 180,
  ),
  DownloadableRegion(
    'iraq',
    'عراق',
    LatLngBounds(const LatLng(29.0, 38.7), const LatLng(37.4, 48.8)),
    level: 'country',
    approxSizeMb: 350,
  ),

  // ---- استان‌های ایران (bbox تقریبی) ----
  ..._iranProvinces,
];

/// فقط استان‌های ایران.
List<DownloadableRegion> get iranProvinceRegions =>
    downloadableRegions.where((r) => r.level == 'province').toList();

final List<DownloadableRegion> _iranProvinces = [
  _p('tehran', 'تهران', 35.45, 50.85, 35.95, 52.05, 90),
  _p('alborz', 'البرز', 35.70, 50.40, 36.30, 51.20, 40),
  _p('isfahan', 'اصفهان', 31.40, 50.90, 33.90, 53.20, 120),
  _p('fars', 'فارس', 27.20, 50.50, 31.70, 55.60, 150),
  _p('khorasan_razavi', 'خراسان رضوی', 33.40, 56.80, 37.80, 61.30, 160),
  _p('khorasan_shomali', 'خراسان شمالی', 36.70, 56.00, 38.30, 58.40, 50),
  _p('khorasan_jonubi', 'خراسان جنوبی', 30.70, 56.80, 34.40, 61.00, 70),
  _p('azarbaijan_sharghi', 'آذربایجان شرقی', 36.70, 45.30, 39.20, 48.00, 90),
  _p('azarbaijan_gharbi', 'آذربایجان غربی', 35.90, 44.00, 39.80, 47.40, 90),
  _p('ardabil', 'اردبیل', 37.40, 47.20, 39.70, 48.90, 45),
  _p('gilan', 'گیلان', 36.60, 48.50, 38.50, 50.60, 55),
  _p('mazandaran', 'مازندران', 35.80, 50.30, 36.90, 54.10, 70),
  _p('golestan', 'گلستان', 36.50, 53.80, 38.10, 56.30, 50),
  _p('qazvin', 'قزوین', 35.40, 48.70, 36.80, 50.60, 40),
  _p('qom', 'قم', 34.30, 50.40, 35.00, 51.60, 25),
  _p('markazi', 'مرکزی', 33.50, 48.90, 35.40, 51.00, 55),
  _p('hamedan', 'همدان', 34.00, 47.80, 35.70, 49.50, 45),
  _p('kermanshah', 'کرمانشاه', 33.70, 45.40, 35.20, 48.10, 55),
  _p('kurdistan', 'کردستان', 34.70, 45.50, 36.40, 48.20, 50),
  _p('ilam', 'ایلام', 32.00, 45.80, 34.20, 48.10, 40),
  _p('lorestan', 'لرستان', 32.80, 46.80, 34.50, 50.00, 50),
  _p('khuzestan', 'خوزستان', 29.90, 47.60, 33.00, 50.50, 110),
  _p('chaharmahal', 'چهارمحال و بختیاری', 31.20, 49.80, 32.80, 51.40, 35),
  _p('kohgiluyeh', 'کهگیلویه و بویراحمد', 30.00, 50.00, 31.50, 51.70, 35),
  _p('bushehr', 'بوشهر', 27.20, 50.40, 30.30, 52.90, 45),
  _p('hormozgan', 'هرمزگان', 25.30, 52.50, 28.60, 59.20, 90),
  _p('kerman', 'کرمان', 26.50, 54.40, 32.00, 59.50, 180),
  _p('yazd', 'یزد', 29.80, 52.80, 33.40, 56.60, 80),
  _p('semnan', 'سمنان', 34.20, 51.80, 37.30, 57.00, 90),
  _p('zanjan', 'زنجان', 35.50, 47.20, 37.20, 49.40, 40),
  _p('sistan', 'سیستان و بلوچستان', 25.00, 58.70, 31.50, 63.40, 160),
];

DownloadableRegion _p(
  String id,
  String name,
  double south,
  double west,
  double north,
  double east,
  double mb,
) {
  return DownloadableRegion(
    'ir_$id',
    name,
    LatLngBounds(LatLng(south, west), LatLng(north, east)),
    level: 'province',
    parentId: 'iran',
    approxSizeMb: mb,
  );
}

const String _tileUrlTemplate =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

final TileLayer _downloadTileLayer = TileLayer(
  urlTemplate: _tileUrlTemplate,
  subdomains: const ['a', 'b', 'c', 'd'],
  userAgentPackageName: 'com.abtin.navigator',
);

/// سرویس مدیریت دانلود نقشهٔ آفلاین (FMTC).
///
/// یک‌بار در شروع با [initialise] راه‌اندازی می‌شود، سپس برای هر منطقه
/// یک store جدا ساخته و کاشی‌های محدودهٔ جغرافیایی دانلود می‌شود.
class OfflineMapDownloadService {
  OfflineMapDownloadService();

  bool _initialised = false;

  Future<void> initialise() async {
    if (_initialised) return;
    await FMTCObjectBoxBackend().initialise();
    _initialised = true;
  }

  FMTCStore storeFor(DownloadableRegion region) => FMTCStore(region.id);

  Future<void> ensureStoreCreated(DownloadableRegion region) async {
    await initialise();
    await storeFor(region).manage.create();
  }

  /// شروع دانلود کاشی‌های یک منطقه. جریان پیشرفت ۰ تا ۱.
  ///
  /// برای استان‌ها zoom تا ۱۶ (جزئیات شهری)، برای کشور تا ۱۴.
  Stream<double> download(DownloadableRegion region) async* {
    await ensureStoreCreated(region);
    final rectRegion = RectangleRegion(region.bounds);
    final maxZoom = region.level == 'province' ? 16 : 14;
    final downloadable = rectRegion.toDownloadable(
      minZoom: 5,
      maxZoom: maxZoom,
      options: _downloadTileLayer,
    );
    final progressStream =
        storeFor(region).download.startForeground(region: downloadable);
    await for (final event in progressStream) {
      yield event.percentageProgress / 100;
    }
  }

  Future<void> cancelDownload(DownloadableRegion region) async {
    await storeFor(region).download.cancel();
  }

  Future<bool> isDownloaded(DownloadableRegion region) async {
    await initialise();
    try {
      final tileCount = await storeFor(region).stats.length;
      return tileCount > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> remove(DownloadableRegion region) async {
    await initialise();
    await storeFor(region).manage.delete();
  }

  Future<List<String>> downloadedStoreIds() async {
    await initialise();
    final ids = <String>[];
    for (final region in downloadableRegions) {
      if (await isDownloaded(region)) ids.add(region.id);
    }
    return ids;
  }

  /// TileProvider که ابتدا کاشی‌های آفلاین ذخیره‌شده را می‌خواند.
  Future<FMTCTileProvider> tileProviderForMap() async {
    await initialise();
    final ids = await downloadedStoreIds();
    final storeNames = ids.isNotEmpty ? ids : <String>['_browse_cache'];
    if (storeNames.first == '_browse_cache') {
      await FMTCStore('_browse_cache').manage.create();
    }
    return FMTCTileProvider(
      stores: {
        for (final id in storeNames) id: BrowseStoreStrategy.readUpdateCreate
      },
    );
  }
}
