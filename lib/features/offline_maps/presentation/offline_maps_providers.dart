import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../data/offline_maps_service.dart';

final offlineMapsServiceProvider = Provider<OfflineMapsService>((ref) {
  return OfflineMapsService();
});

/// کیفیت انتخاب‌شده برای دانلود (در کل صفحه مشترک است).
final selectedMapQualityProvider =
    StateProvider<MapQuality>((ref) => MapQuality.standard);

/// فهرست منطقه‌های آفلاینِ دانلودشده روی دستگاه.
final offlineRegionsProvider =
    FutureProvider.autoDispose<List<OfflineRegion>>((ref) async {
  return ref.watch(offlineMapsServiceProvider).listRegions();
});
