import 'package:geolocator/geolocator.dart';

/// نتیجه‌ی بررسی مجوز و وضعیت GPS، برای نمایش پیام مناسب در UI.
enum LocationReadiness { ready, permissionDenied, permissionDeniedForever, serviceDisabled }

class LocationPermissionFlow {
  /// طبق درخواست: «هنگام باز شدن مجوز GPS رو بگیرد و در صورت خاموش بودن،
  /// دستور روشن شدن GPS اجرا شود». این متد فقط یک‌بار (موقع باز شدن اپ)
  /// صدا زده می‌شود؛ چون تعاملی است (ممکن است دیالوگ سیستمی/صفحه‌ی تنظیمات
  /// باز کند).
  static Future<LocationReadiness> ensureReady() async {
    // 1) بررسی روشن بودن سرویس GPS دستگاه
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // این متد در اندروید فقط صفحه‌ی تنظیمات GPS را باز می‌کند و بلافاصله
      // برمی‌گردد — نتیجه‌اش این نیست که کاربر GPS را روشن کرده باشد؛ فقط
      // یعنی صفحه‌ی تنظیمات با موفقیت باز شد. بنابراین اینجا دیگر بلافاصله
      // recheck نمی‌کنیم (چون همیشه false برمی‌گردد، چون کاربر هنوز فرصت
      // نکرده تغییری بدهد) — به‌جایش serviceDisabled را برمی‌گردانیم و
      // این‌که کاربر واقعاً کِی GPS را روشن می‌کند را
      // [checkStatus] + گوش‌دادن به [Geolocator.getServiceStatusStream]
      // در gps_providers.dart به‌صورت زنده رصد می‌کند.
      await Geolocator.openLocationSettings();
      return LocationReadiness.serviceDisabled;
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

  /// نسخه‌ی «فقط بررسی» و غیرتعاملی — هیچ دیالوگ/صفحه‌ی تنظیماتی باز نمی‌کند،
  /// فقط وضعیت فعلی را می‌خواند. برای رصد زنده‌ی تغییرات (وقتی کاربر خودش از
  /// تنظیمات دستگاه GPS را روشن/مجوز را می‌دهد و به اپ برمی‌گردد) استفاده
  /// می‌شود، تا هر بار کاربر GPS را روشن می‌کند دوباره یک صفحه‌ی تنظیمات
  /// جدید باز نشود.
  static Future<LocationReadiness> checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationReadiness.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return LocationReadiness.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationReadiness.permissionDeniedForever;
    }
    return LocationReadiness.ready;
  }
}
