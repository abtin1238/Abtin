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

  /// نسخه‌ی «بررسی + تلاش مجدد برای گرفتن مجوز»، برای وقتی مجوز فقط رد شده
  /// باشد (نه برای همیشه). طبق درخواست: «اگه دسترسی داده نشده بود اپ دوباره
  /// سوال کنه». برخلاف [ensureReady]:
  ///  - اگر GPS خاموش باشد، صفحه‌ی تنظیمات GPS را دوباره باز نمی‌کند (آن را
  ///    [Geolocator.getServiceStatusStream] در gps_providers.dart جدا رصد
  ///    می‌کند)، فقط serviceDisabled را برمی‌گرداند.
  ///  - اگر مجوز فقط "denied" باشد (کاربر یک‌بار رد کرده ولی گزینه‌ی
  ///    «دیگر نپرس» را نزده)، اندروید/iOS اجازه می‌دهند دوباره دیالوگ
  ///    سیستمی نشان داده شود؛ پس [Geolocator.requestPermission] دوباره صدا
  ///    زده می‌شود — دقیقاً همان رفتاری که خواسته شده.
  ///  - اگر "deniedForever" باشد، سیستم‌عامل دیگر دیالوگ را نشان نمی‌دهد؛
  ///    این حالت فقط گزارش می‌شود (باز کردن صفحه‌ی تنظیمات اپ برای این حالت
  ///    با ضربه‌ی کاربر روی بنر هشدار توسط [retryFromUserTap] انجام می‌شود،
  ///    نه به‌صورت خودکار در هر رصد چرخه‌ی حیات اپ).
  static Future<LocationReadiness> checkStatusAndRetryIfDenied() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationReadiness.serviceDisabled;

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

  /// وقتی کاربر خودش دستی روی بنر هشدار GPS ضربه می‌زند: اگر مجوز برای
  /// همیشه رد شده، چون دیگر دیالوگ سیستمی امکان‌پذیر نیست، صفحه‌ی تنظیمات
  /// خودِ اپ باز می‌شود تا کاربر دستی مجوز را فعال کند. اگر فقط denied
  /// ساده باشد، به‌جایش مستقیماً دوباره درخواست مجوز می‌شود.
  static Future<LocationReadiness> retryFromUserTap() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return LocationReadiness.permissionDeniedForever;
    }
    return checkStatusAndRetryIfDenied();
  }
}
