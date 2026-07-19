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

  @override
  void initState() {
    super.initState();
    _updateScreenLocation();
  }

  @override
  void didUpdateWidget(covariant VehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // با تغییر موقعیت خودرو یا حرکت دوربین (که باعث rebuild والد می‌شود) دوباره محاسبه کن
    _updateScreenLocation();
  }

  Future<void> _updateScreenLocation() async {
    final controller = widget.mapController;
    if (controller == null) return;
    try {
      final s = await controller.toScreenLocation(widget.position);
      if (mounted) setState(() => _screen = s);
    } catch (_) {
      // نقشه هنوز آماده نیست؛ نادیده بگیر
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _screen;
    if (s == null) return const SizedBox.shrink();
    return Positioned(
      left: s.x.toDouble() - 22,
      top: s.y.toDouble() - 22,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: widget.headingDeg * 3.1415926535 / 180,
          child: widget.vehicle == VehicleType.arrow
              ? _ArrowIcon()
              : _CarIcon(),
        ),
      ),
    );
  }
}

class _ArrowIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.homeAccent.withOpacity(.18),
      ),
      child: const Icon(Icons.navigation_rounded, color: AppColors.homeAccent, size: 32),
    );
  }
}

class _CarIcon extends StatelessWidget {
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
