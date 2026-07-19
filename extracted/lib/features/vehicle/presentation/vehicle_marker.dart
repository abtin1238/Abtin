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
class VehicleMarker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (mapController == null) return const SizedBox.shrink();

    return FutureBuilder<Point<num>>(
      future: mapController!.toScreenLocation(position),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final screen = snapshot.data!;
        return Positioned(
          left: screen.x.toDouble() - 22,
          top: screen.y.toDouble() - 22,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: headingDeg * 3.1415926535 / 180,
              child: vehicle == VehicleType.arrow
                  ? _ArrowIcon()
                  : _CarIcon(),
            ),
          ),
        );
      },
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
