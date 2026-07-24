import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/theme/app_colors.dart';
import 'vehicle_provider.dart';

/// مارکر خودرو/پیکان روی نقشه.
///
/// maplibre_gl لایه‌ای برای رندر مستقیم ویجت فلاتر یا مدل glTF روی نقشه سه‌بعدی
/// ندارد، پس این ویجت به‌صورت Overlay بالای نقشه قرار می‌گیرد و با
/// `mapController.toScreenLocation()` هر بار که دوربین/موقعیت تغییر کند،
/// مختصات صفحه‌اش به‌روزرسانی می‌شود — همان تکنیک رایج برای مارکرهای پویا
/// روی MapLibre/Mapbox در Flutter.
///
/// برای حالت خودروی سه‌بعدی (GLB)، این ویجت فعلاً یک آیکون دوبعدی نشان می‌دهد؛
/// رندر واقعی مدل روی صحنه سه‌بعدی نقشه به یک لایه‌ی Native اختصاصی نیاز دارد
/// (فاز بعد).
class VehicleMarker extends StatefulWidget {
  final MapLibreMapController? mapController;
  final LatLng position;
  final double headingDeg;
  final VehicleType vehicle;

  /// وقتی true است یعنی دوربین در حال دنبال‌کردن خودرو است (همان چیزی که در
  /// home_screen با `_cameraFollowsVehicle` کنترل می‌شود؛ دوربین با
  /// `tilt: 55` و `bearing: headingDeg` روی خودرو قفل می‌شود).
  ///
  /// نکته‌ی مهم (رفع باگ «پیکان اصلاً روی نقشه نمایش داده نمی‌شود»):
  /// `mapController.toScreenLocation()` در maplibre_gl، وقتی دوربین tilt
  /// (سه‌بعدی/خمیده) دارد، در خیلی از نسخه‌ها مختصات غلط برمی‌گرداند — نه
  /// null و نه خطا، فقط یک پیکسل کاملاً خارج از صفحه (مثلاً منفی یا خیلی
  /// بزرگ) — پس fallback قبلی (که فقط وقتی نتیجه null/exception بود فعال
  /// می‌شد) هیچ‌وقت اجرا نمی‌شد و پیکان نامرئی می‌ماند.
  ///
  /// راه‌حل استاندارد همه‌ی اپ‌های ناوبری (گوگل‌مپس، Waze): وقتی دوربین
  /// دنبال خودرو است، اصلاً به مختصات محاسبه‌شده روی صفحه اعتماد نمی‌کنیم؛
  /// چون camera.target دقیقاً برابر موقعیت خودرو و camera.bearing دقیقاً
  /// برابر heading خودرو است، خودِ خودرو همیشه روی یک نقطه‌ی ثابت از صفحه
  /// (وسط، کمی پایین‌تر از مرکز به‌خاطر پرسپکتیو دوربین خمیده) می‌نشیند و
  /// این نقشه است که زیرش می‌چرخد/پن می‌شود، نه پیکان. در این حالت پیکان
  /// را مستقیم رو به بالا (بدون چرخش اضافه) روی همان نقطه‌ی ثابت می‌کشیم.
  ///
  /// وقتی کاربر خودش نقشه را جابه‌جا کرده (`followsCamera = false`)، دوربین
  /// دیگر دنبال خودرو نیست، پس باید از مختصات واقعی (`toScreenLocation`) و
  /// چرخش واقعی heading استفاده کنیم — دقیقاً رفتار قبلی.
  final bool followsCamera;

  const VehicleMarker({
    super.key,
    required this.mapController,
    required this.position,
    required this.headingDeg,
    required this.vehicle,
    this.followsCamera = false,
  });

  @override
  State<VehicleMarker> createState() => _VehicleMarkerState();
}

class _VehicleMarkerState extends State<VehicleMarker> {
  Point<num>? _screen;
  Timer? _refreshTimer;

  /// چرخش تجمعی و پیوسته بر حسب «دور» (turns)، بدون قطع/جهش هنگام عبور از
  /// مرز ۰/۳۶۰ درجه. مقدار مطلق است (می‌تواند از ۱ بیشتر یا منفی شود) تا
  /// AnimatedRotation همیشه از کوتاه‌ترین مسیر بچرخد، نه این‌که مثلاً از ۳۵۹
  /// درجه یک دور کامل معکوس بزند تا به ۰ برسد.
  double _rotationTurns = 0;

  @override
  void initState() {
    super.initState();
    _rotationTurns = widget.headingDeg / 360.0;
    _syncFollowMode();
  }

  @override
  void didUpdateWidget(covariant VehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.followsCamera != oldWidget.followsCamera) {
      _syncFollowMode();
    } else if (!widget.followsCamera) {
      // با تغییر موقعیت خودرو یا حرکت دوربین (که باعث rebuild والد می‌شود) دوباره محاسبه کن
      _updateScreenLocation();
    }
    if (!widget.followsCamera) {
      // فقط در حالت پیرویِ دستی از heading واقعی می‌چرخیم؛ در حالت
      // followsCamera پیکان همیشه رو به بالا ثابت می‌ماند (پایین‌تر توضیح
      // داده شده) چون دوربین خودش با bearing = heading می‌چرخد.
      _advanceRotation(widget.headingDeg);
    }
  }

  /// بین دو حالت «دوربین دنبال خودرو» و «کاربر خودش نقشه را جابه‌جا کرده»
  /// سوییچ می‌کند:
  /// - followsCamera == true: تایمر/توScreenLocation را متوقف می‌کنیم (چون با
  ///   دوربین tilt‌دار مختصات غلط برمی‌گرداند) و پیکان رو به بالا و روی نقطه‌ی
  ///   ثابت صفحه می‌ایستد.
  /// - followsCamera == false: توScreenLocation واقعی را دوباره فعال می‌کنیم.
  void _syncFollowMode() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (widget.followsCamera) {
      // پیکان همیشه رو به بالا؛ چرخش اضافه لازم نیست (نقشه خودش می‌چرخد).
      _rotationTurns = _rotationTurns.roundToDouble();
      return;
    }
    _updateScreenLocation();
    // نکته‌ی مهم (رفع باگ «پوینتر نمایش داده نمی‌شود»):
    // بازمحاسبه‌ی موقعیت صرفاً با didUpdateWidget/listener کافی نیست، چون وقتی
    // نقشه هنوز کاملاً بارگذاری نشده toScreenLocation شکست می‌خورد و بدون تلاش
    // دوباره، مارکر برای همیشه مخفی می‌ماند. این تایمر تا وقتی ویجت زنده است
    // و followsCamera=false، هر ۲۰۰ میلی‌ثانیه دوباره تلاش می‌کند تا مارکر
    // حتماً ظاهر شود.
    _refreshTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _updateScreenLocation(),
    );
  }

  /// چرخش را از کوتاه‌ترین مسیر به سمت heading جدید پیش می‌برد (مثلاً از ۳۵۰
  /// درجه به ۱۰ درجه، ۲۰ درجه جلو می‌رود، نه ۳۴۰ درجه عقب).
  void _advanceRotation(double newHeadingDeg) {
    final newTurnsRaw = newHeadingDeg / 360.0;
    final currentFraction = _rotationTurns - _rotationTurns.floorToDouble();
    var delta = newTurnsRaw - currentFraction;
    delta -= delta.roundToDouble();
    _rotationTurns += delta;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateScreenLocation() async {
    final controller = widget.mapController;
    if (controller == null) return;
    try {
      final s = await controller.toScreenLocation(widget.position);
      if (!mounted) return;
      // نکته‌ی مهم (رفع نهایی باگ «پیکان هنگام اسکرول لحظه‌ای غیب می‌شود»):
      // toScreenLocation در maplibre_gl گاهی (مخصوصاً وسط تغییر tilt/بیرون
      // از محدوده‌ی صفحه) عددی برمی‌گرداند که نه null است و نه خطا می‌دهد،
      // ولی کاملاً بیرون از صفحه‌ی قابل‌مشاهده است. قبلاً هر نتیجه‌ای (حتی
      // غلط) مستقیم استفاده می‌شد، پس پیکان همان لحظه از دید خارج می‌شد. الان
      // اگر نتیجه به‌طور محسوسی خارج از کادر صفحه باشد، آن را نادیده
      // می‌گیریم و آخرین موقعیت معتبر را نگه می‌داریم (تایمر پایین دوباره
      // تلاش می‌کند)، تا پیکان همیشه «چسبیده» به آخرین نقطه‌ی درست GPS بماند
      // و هرگز محو نشود.
      final screenSize = MediaQuery.of(context).size;
      const margin = 200.0; // کمی حاشیه برای مارکرهایی که تازه لبه‌ی صفحه هستند
      final withinBounds = s.x >= -margin &&
          s.y >= -margin &&
          s.x <= screenSize.width + margin &&
          s.y <= screenSize.height + margin;
      if (withinBounds) {
        setState(() => _screen = s);
      }
    } catch (_) {
      // نقشه هنوز آماده نیست؛ تایمر بالا دوباره تلاش می‌کند
    }
  }

  @override
  Widget build(BuildContext context) {
    // نکته‌ی مهم (ریشه‌ی واقعی باگ «کل صفحه خراب/محو می‌شود» — نه فقط پیکان):
    // نسخه‌ی قبلی این متد Positioned را داخل LayoutBuilder برمی‌گرداند.
    // LayoutBuilder خودش یک RenderObject واقعی می‌سازد و بین Stack و
    // Positioned قرار می‌گیرد؛ Positioned فقط وقتی معتبر است که (با حذف
    // ویجت‌های شفاف مثل StatefulWidget) مستقیماً زیر یک Stack باشد. نتیجه‌ی
    // این ترکیب، خطای معروف فلاتر «Incorrect use of ParentDataWidget» در هر
    // فریم بود — دقیقاً همان چیزی که باعث می‌شد کل صفحه (نه فقط مارکر) بعد
    // از بیلد خراب/محو به‌نظر برسد. الان Positioned مستقیماً از build()
    // برگردانده می‌شود (بدون هیچ RenderObjectWidget واسط)، و برای حالت
    // fallback (وقتی مختصات دقیق هنوز آماده نیست) به‌جای constraints از
    // MediaQuery برای وسط‌چین‌کردن استفاده می‌شود.
    const markerSize = 52.0;
    final screenSize = MediaQuery.of(context).size;

    double left;
    double top;
    if (widget.followsCamera) {
      // نکته‌ی مهم (رفع باگ «پیکان دقیق روی موقعیت GPS نیست/کنار جاده
      // می‌ایستد»): وقتی دوربین دنبال خودرو است، camera.target دقیقاً برابر
      // موقعیت خودرو است، پس دیگر لازم نیست (و نباید) به toScreenLocation
      // اعتماد کنیم. اما نکته‌ی کلیدی که نسخه‌ی قبلی اشتباه فرض کرده بود:
      // در MapLibre/Mapbox GL، وقتی هیچ padding‌ای روی دوربین تنظیم نشده
      // باشد (و در کل این پروژه — چه در CameraPosition اولیه، چه در
      // انیمیشن‌های دنبال‌کردن خودرو — هیچ‌جا padding داده نشده)، نقطه‌ی
      // camera.target همیشه دقیقاً روی مرکز هندسی صفحه (۵۰٪ عرض، ۵۰٪ ارتفاع)
      // قرار می‌گیرد؛ tilt فقط زاویه‌ی دید را عوض می‌کند، نه نقطه‌ی تصویر
      // target روی صفحه. نسخه‌ی قبلی این نقطه را دستی و بدون مبنا به ۶۲٪
      // ارتفاع منتقل کرده بود (احتمالاً با این فرض غلط که پرسپکتیو دوربین
      // خمیده target را پایین‌تر می‌برد) — نتیجه این بود که پیکان همیشه با
      // یک افست ثابت (حدود ۱۲٪ ارتفاع صفحه) پایین‌تر از موقعیت واقعی GPS/جاده
      // کشیده می‌شد، دقیقاً همان چیزی که در اسکرین‌شات دیده می‌شود (پیکان
      // پایین‌تر از نقطه‌ای که مسیر سبز به آن ختم می‌شود). الان دقیقاً روی
      // مرکز صفحه ثابت می‌شود تا با نقطه‌ای که MapLibre واقعاً روی آن رندر
      // می‌کند یکی باشد.
      left = screenSize.width / 2 - markerSize / 2;
      top = screenSize.height / 2 - markerSize / 2;
    } else {
      final s = _screen;
      left = s != null
          ? s.x.toDouble() - markerSize / 2
          : screenSize.width / 2 - markerSize / 2;
      top = s != null
          ? s.y.toDouble() - markerSize / 2
          : screenSize.height / 2 - markerSize / 2;
    }
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        // چرخش نرم و پیوسته به‌جای جهش ناگهانی — هر تغییر heading با
        // انیمیشن ۳۰۰ میلی‌ثانیه‌ای از نزدیک‌ترین جهت طی می‌شود.
        child: AnimatedRotation(
          turns: _rotationTurns,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: widget.vehicle == VehicleType.arrow
              ? Image.asset(
                  'assets/images/nav_arrow.png',
                  width: markerSize,
                  height: markerSize,
                  fit: BoxFit.contain,
                )
              : const _CarIcon(),
        ),
      ),
    );
  }
}

class _CarIcon extends StatelessWidget {
  const _CarIcon();

  @override
  Widget build(BuildContext context) {
    // جایگزین موقت آیکون تا لایه‌ی رندر سه‌بعدی GLB در فاز بعد اضافه شود.
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.homeAccent.withOpacity(.18),
        border: Border.all(color: AppColors.homeAccent, width: 2),
      ),
      child: const Icon(Icons.directions_car_rounded, color: AppColors.homeAccent, size: 26),
    );
  }
}
