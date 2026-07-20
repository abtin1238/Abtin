import 'package:maplibre_gl/maplibre_gl.dart';
import 'iran_provinces.dart';

/// کیفیت (و در نتیجه حجم) دانلود نقشه‌ی آفلاین.
enum MapQuality { smallest, standard, detailed }

extension MapQualityInfo on MapQuality {
  String get label {
    switch (this) {
      case MapQuality.smallest:
        return 'کم‌حجم‌ترین';
      case MapQuality.standard:
        return 'استاندارد';
      case MapQuality.detailed:
        return 'پرجزئیات';
    }
  }

  String get desc {
    switch (this) {
      case MapQuality.smallest:
        return 'فقط جاده‌های اصلی — کمترین فضا';
      case MapQuality.standard:
        return 'مناسب برای اکثر مسیریابی‌ها';
      case MapQuality.detailed:
        return 'تمام خیابان‌ها — بیشترین فضا';
    }
  }

  ({double min, double max}) get zoom {
    switch (this) {
      case MapQuality.smallest:
        return (min: 5, max: 10);
      case MapQuality.standard:
        return (min: 5, max: 12);
      case MapQuality.detailed:
        return (min: 5, max: 14);
    }
  }
}

/// سرویس مدیریت نقشه‌های آفلاین بر پایه‌ی قابلیت Offline خود MapLibre.
///
/// تایل‌های استایل تیره‌ی OpenFreeMap برای محدوده‌ی هر استان دانلود و روی دستگاه
/// ذخیره می‌شوند؛ پس از آن نقشه بدون اینترنت هم در همان محدوده کار می‌کند.
class OfflineMapsService {
  static const String styleUrl = 'https://tiles.openfreemap.org/styles/dark';

  static bool _limitSet = false;

  /// سقف تعداد تایل پیش‌فرض MapLibre پایین است؛ آن را بالا می‌بریم تا دانلود
  /// یک استان کامل ممکن شود.
  Future<void> _ensureTileLimit() async {
    if (_limitSet) return;
    await setOfflineTileCountLimit(2000000);
    _limitSet = true;
  }

  /// تخمین بسیار تقریبی حجم دانلود (مگابایت) برای نمایش به کاربر.
  double estimateSizeMb(Province p, MapQuality q) {
    final base = switch (q) {
      MapQuality.smallest => 6.0,
      MapQuality.standard => 22.0,
      MapQuality.detailed => 90.0,
    };
    return base * p.areaFactor;
  }

  Future<OfflineRegion> downloadProvince(
    Province province,
    MapQuality quality, {
    required void Function(double progress) onProgress,
  }) async {
    await _ensureTileLimit();
    final z = quality.zoom;
    final definition = OfflineRegionDefinition(
      bounds: province.bounds,
      mapStyleUrl: styleUrl,
      minZoom: z.min,
      maxZoom: z.max,
    );
    return downloadOfflineRegion(
      definition,
      metadata: {
        'province': province.id,
        'name': province.name,
        'quality': quality.name,
      },
      onEvent: (status) {
        if (status is InProgress) {
          onProgress(status.progress / 100.0);
        } else if (status is Success) {
          onProgress(1.0);
        }
      },
    );
  }

  Future<List<OfflineRegion>> listRegions() => getListOfRegions();

  Future<void> deleteRegion(int id) => deleteOfflineRegion(id);

  /// حذف تمام منطقه‌های مربوط به یک استان (برای «به‌روزرسانی» یا «حذف»).
  Future<void> deleteProvince(String provinceId) async {
    final regions = await getListOfRegions();
    for (final r in regions) {
      if (r.metadata['province'] == provinceId) {
        await deleteOfflineRegion(r.id);
      }
    }
  }
}
