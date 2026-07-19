import 'package:geolocator/geolocator.dart';

/// نتیجه‌ی بررسی مجوز و وضعیت GPS، برای نمایش پیام مناسب در UI.
enum LocationReadiness { ready, permissionDenied, permissionDeniedForever, serviceDisabled }

class LocationPermissionFlow {
  /// طبق درخواست: «هنگام باز شدن مجوز GPS رو بگیرد و در صورت خاموش بودن،
  /// دستور روشن شدن GPS اجرا شود».
  static Future<LocationReadiness> ensureReady() async {
    // 1) بررسی روشن بودن سرویس GPS دستگاه
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // این متد در اندروید دیالوگ سیستمی "روشن کردن GPS" را نشان می‌دهد.
      final opened = await Geolocator.openLocationSettings();
      if (!opened) return LocationReadiness.serviceDisabled;
      final recheck = await Geolocator.isLocationServiceEnabled();
      if (!recheck) return LocationReadiness.serviceDisabled;
    }

    // 2) بررسی/درخواست مجوز دسترسی به موقعیت
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationReadiness.permissionDenied;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationReadiness.permissionDeniedForever;
    }

    return LocationReadiness.ready;
  }
}
