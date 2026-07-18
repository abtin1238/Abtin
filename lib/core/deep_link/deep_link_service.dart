import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// مقصدی که از یک دیپ‌لینک بیرونی (مثل اسنپ) دریافت شده.
class DeepLinkDestination {
  final double lat;
  final double lng;
  final String? label;

  const DeepLinkDestination({required this.lat, required this.lng, this.label});
}

/// این کلاس درخواست‌های دیپ‌لینک با اسکیم `abtin://navigate?lat=..&lng=..&label=..`
/// را می‌گیرد. برای فعال‌شدن ۱۰۰٪ روی اندروید، intent-filter مربوطه باید در
/// AndroidManifest.xml ثبت شده باشد (فایل مرجع در android_manifest_reference/
/// موجود است).
///
/// مثال لینکی که اسنپ یا هر اپ دیگری می‌تواند صدا بزند:
///   abtin://navigate?lat=35.7000&lng=51.4000&label=مقصد%20شما
class DeepLinkService {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  final _controller = StreamController<DeepLinkDestination>.broadcast();

  Stream<DeepLinkDestination> get destinations => _controller.stream;

  Future<void> init() async {
    // 1) اگر اپ از طریق یک لینک باز شده (Cold start)
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handle(initial);

    // 2) لینک‌هایی که وقتی اپ باز است دریافت می‌شوند (Warm start)
    _sub = _appLinks.uriLinkStream.listen(_handle);
  }

  void _handle(Uri uri) {
    if (uri.scheme != 'abtin' || uri.host != 'navigate') return;
    final lat = double.tryParse(uri.queryParameters['lat'] ?? '');
    final lng = double.tryParse(uri.queryParameters['lng'] ?? '');
    if (lat == null || lng == null) return;
    _controller.add(DeepLinkDestination(
      lat: lat,
      lng: lng,
      label: uri.queryParameters['label'],
    ));
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

/// آخرین مقصد دریافت‌شده از دیپ‌لینک — صفحه اصلی به این گوش می‌دهد و
/// دوربین/مارکر مقصد را به‌روزرسانی می‌کند.
final deepLinkDestinationProvider = StreamProvider<DeepLinkDestination>((ref) {
  return ref.watch(deepLinkServiceProvider).destinations;
});
