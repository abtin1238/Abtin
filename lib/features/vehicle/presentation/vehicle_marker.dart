import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/theme/app_colors.dart';
import 'nav_arrow_painter.dart';
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

  const VehicleMarker({
    super.key,
    required this.mapController,
    required this.position,
    required this.headingDeg,
    required this.vehicle,
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
    _updateScreenLocation();
    // نکته‌ی مهم (رفع باگ «پوینتر نمایش داده نمی‌شود»):
    // بازمحاسبه‌ی موقعیت صرفاً با didUpdateWidget/listener کافی نیست، چون وقتی
    // نقشه هنوز کاملاً بارگذاری نشده toScreenLocation شکست می‌خورد و بدون تلاش
    // دوباره، مارکر برای همیشه مخفی می‌ماند. این تایمر تا وقتی ویجت زنده است
    // هر ۲۰۰ میلی‌ثانیه دوباره تلاش می‌کند تا مارکر حتماً ظاهر شود.
    _refreshTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _updateScreenLocation(),
    );
  }

  @override
  void didUpdateWidget(covariant VehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // با تغییر موقعیت خودرو یا حرکت دوربین (که باعث rebuild والد می‌شود) دوباره محاسبه کن
    _updateScreenLocation();
    _advanceRotation(widget.headingDeg);
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
      if (mounted) setState(() => _screen = s);
    } catch (_) {
      // نقشه هنوز آماده نیست؛ تایمر بالا دوباره تلاش می‌کند
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _screen;
    if (s == null) return const SizedBox.shrink();
    const markerSize = 52.0;
    return Positioned(
      left: s.x.toDouble() - markerSize / 2,
      top: s.y.toDouble() - markerSize / 2,
      child: IgnorePointer(
        // چرخش نرم و پیوسته به‌جای جهش ناگهانی — هر تغییر heading با انیمیشن
        // ۳۰۰ میلی‌ثانیه‌ای از نزدیک‌ترین جهت طی می‌شود.
        child: AnimatedRotation(
          turns: _rotationTurns,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: widget.vehicle == VehicleType.arrow
              ? const NavArrow(size: markerSize)
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
