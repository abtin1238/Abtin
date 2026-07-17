import 'package:latlong2/latlong.dart';

import 'route_info.dart';

/// اعداد فارسی برای نمایش در UI (مطابق تصاویر مرجع).
String toFa(Object input) {
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var s = '$input';
  for (var i = 0; i < en.length; i++) {
    s = s.replaceAll(en[i], fa[i]);
  }
  return s;
}

/// وضعیت زنده‌ی ناوبری — تنها منبع حقیقت برای نوار بالا، سرعت‌سنج و تابلوی محدودیت.
///
/// این کلاس کاملاً داینامیک است: مقادیر آن توسط [NavigationController]
/// از خروجی موتور مسیریابی آفلاین + GPS + شتاب‌سنج به‌روزرسانی می‌شوند و
/// هیچ متن ثابتی در UI باقی نمی‌ماند.
class NavigationState {
  /// آیا ناوبری فعال است؟ (اگر نه، نوار بالا نمایش داده نمی‌شود)
  final bool isNavigating;

  /// مانور بعدی (پیچ به راست/چپ، دوربرگردان، ...) خوانده‌شده از مسیر.
  final ManeuverStep? nextManeuver;

  /// فاصله تا مانور بعدی (متر) — برای «۳۵۰ متر».
  final double distanceToManeuverMeters;

  /// مسافت باقی‌مانده تا مقصد (متر).
  final double remainingDistanceMeters;

  /// زمان باقی‌مانده تا مقصد.
  final Duration remainingTime;

  /// زمان تخمینی رسیدن.
  final DateTime? eta;

  /// سرعت لحظه‌ای (km/h) — تلفیق GPS + شتاب‌سنج (فیلتر کالمن).
  final double currentSpeedKmh;

  /// محدودیت سرعت مسیر جاری (km/h) خوانده‌شده از داده‌ی نقشه (null یعنی نامشخص).
  final int? speedLimitKmh;

  /// جهت حرکت (درجه، شمال = ۰) برای قطب‌نما و چرخش نقشه.
  final double headingDeg;

  /// موقعیت فعلی خودرو روی نقشه.
  final LatLng? position;

  /// مقصد جاری (برای نمایش نشانگر روی نقشه) — null یعنی مسیریابی فعال نیست.
  final LatLng? destination;

  /// خطِ کاملِ مسیرِ جاری (برای رندرِ نقشه). خالی یعنی مسیری وجود ندارد.
  final List<LatLng> routePolyline;

  const NavigationState({
    this.isNavigating = false,
    this.nextManeuver,
    this.distanceToManeuverMeters = 0,
    this.remainingDistanceMeters = 0,
    this.remainingTime = Duration.zero,
    this.eta,
    this.currentSpeedKmh = 0,
    this.speedLimitKmh,
    this.headingDeg = 0,
    this.position,
    this.destination,
    this.routePolyline = const [],
  });

  /// آیا سرعت فعلی از محدودیت مجاز عبور کرده است؟
  bool get isOverLimit =>
      speedLimitKmh != null && currentSpeedKmh > speedLimitKmh! + 0.5;

  /// آیا به محدوده‌ی سرعت نزدیک شده‌ایم؟ (نمایش تابلوی محدودیت)
  /// تابلو زمانی دیده می‌شود که محدودیتی وجود دارد و سرعت به آن نزدیک/فراتر است.
  bool get shouldShowSpeedLimit {
    if (speedLimitKmh == null) return false;
    return currentSpeedKmh >= speedLimitKmh! - 15;
  }

  /// متن فاصله تا مانور با واحد مناسب (فارسی).
  String get distanceToManeuverLabel {
    final d = distanceToManeuverMeters;
    if (d >= 1000) {
      return '${toFa((d / 1000).toStringAsFixed(1))} کیلومتر';
    }
    // گرد کردن به مضرب ۱۰ برای نمایش تمیز.
    final rounded = (d / 10).round() * 10;
    return '${toFa(rounded)} متر';
  }

  /// متن مسافت باقی‌مانده (فارسی).
  String get remainingDistanceLabel {
    final d = remainingDistanceMeters;
    if (d >= 1000) {
      return '${toFa((d / 1000).toStringAsFixed(1))} کیلومتر';
    }
    return '${toFa((d / 10).round() * 10)} متر';
  }

  /// متن زمان باقی‌مانده (فارسی).
  String get remainingTimeLabel {
    final m = remainingTime.inMinutes;
    if (m >= 60) {
      return '${toFa(m ~/ 60)} ساعت و ${toFa(m % 60)} دقیقه';
    }
    return '${toFa(m)} دقیقه';
  }

  /// متن زمان رسیدن (HH:MM فارسی).
  String get etaLabel {
    final t = eta;
    if (t == null) return '--:--';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return toFa('$hh:$mm');
  }

  NavigationState copyWith({
    bool? isNavigating,
    ManeuverStep? nextManeuver,
    double? distanceToManeuverMeters,
    double? remainingDistanceMeters,
    Duration? remainingTime,
    DateTime? eta,
    double? currentSpeedKmh,
    int? speedLimitKmh,
    bool clearSpeedLimit = false,
    double? headingDeg,
    LatLng? position,
    LatLng? destination,
    bool clearDestination = false,
    List<LatLng>? routePolyline,
  }) =>
      NavigationState(
        isNavigating: isNavigating ?? this.isNavigating,
        nextManeuver: nextManeuver ?? this.nextManeuver,
        distanceToManeuverMeters:
            distanceToManeuverMeters ?? this.distanceToManeuverMeters,
        remainingDistanceMeters:
            remainingDistanceMeters ?? this.remainingDistanceMeters,
        remainingTime: remainingTime ?? this.remainingTime,
        eta: eta ?? this.eta,
        currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
        speedLimitKmh:
            clearSpeedLimit ? null : (speedLimitKmh ?? this.speedLimitKmh),
        headingDeg: headingDeg ?? this.headingDeg,
        position: position ?? this.position,
        destination:
            clearDestination ? null : (destination ?? this.destination),
        routePolyline: routePolyline ?? this.routePolyline,
      );
}
