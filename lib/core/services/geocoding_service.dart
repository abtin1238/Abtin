import 'package:latlong2/latlong.dart';

import '../../features/navigation/domain/entities/place.dart';
import '../../features/search/data/offline_search_service.dart';

/// ژئوکدینگ **آفلاین‌اول** روی POIهای بسته‌شده + تاریخچه محلی.
///
/// شبکه فقط به‌عنوان لایه اختیاری توسعه در نظر گرفته می‌شود؛
/// مسیر اصلی محصول بدون اینترنت کار می‌کند.
class GeocodingService {
  GeocodingService({OfflineSearchService? offline})
      : _offline = offline ?? OfflineSearchService();

  final OfflineSearchService _offline;

  /// جستجوی متنی آفلاین.
  Future<List<Place>> search(
    String query, {
    LatLng? near,
    int limit = 20,
  }) async {
    final hits = await _offline.search(query, near: near);
    if (hits.length <= limit) return hits;
    return hits.take(limit).toList();
  }

  /// معکوس: نزدیک‌ترین POI به مختصات.
  Future<Place?> reverse(LatLng point) async {
    final all = await _offline.allPois();
    if (all.isEmpty) {
      return Place(
        id: 'rev_${point.latitude}_${point.longitude}',
        title: 'موقعیت انتخاب‌شده',
        subtitle:
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        location: point,
      );
    }
    const dist = Distance();
    Place? best;
    var bestD = double.infinity;
    for (final p in all) {
      final d = dist.as(LengthUnit.Meter, point, p.location);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    if (best == null) return null;
    return Place(
      id: best.id,
      title: best.title,
      subtitle: best.subtitle.isEmpty
          ? '${bestD.round()} متر'
          : '${best.subtitle} · ${bestD.round()} متر',
      location: best.location,
      category: best.category,
      distanceKm: bestD / 1000.0,
    );
  }

  Future<List<Place>> byCategory(PlaceCategory cat, {LatLng? near}) =>
      _offline.byCategory(cat, near: near);

  Future<List<Place>> allOfflinePois() => _offline.allPois();
}

class GeocodingException implements Exception {
  final String message;
  GeocodingException(this.message);
  @override
  String toString() => message;
}
