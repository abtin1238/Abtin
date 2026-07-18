import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/permissions/location_permission_flow.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/deep_link/deep_link_service.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../gps/presentation/gps_providers.dart';
import '../../gps/data/location_service.dart';
import '../../vehicle/presentation/vehicle_marker.dart';
import '../../vehicle/presentation/vehicle_provider.dart';
import '../../routing/presentation/routing_providers.dart';
import 'destination_provider.dart';
import 'dart:math' as math;

/// صفحه اصلی ناوبری — معادل index.html
///
/// نکته مهم: styleString زیر باید به یک آدرس Style JSON واقعی (مثل MapTiler یا
/// یک سرور Vector Tile خودتان) اشاره کند. در این مرحله (نقشه آنلاین) از
/// demotiles عمومی MapLibre استفاده شده که برای تست کافی است ولی برای
/// Production باید با یک style حرفه‌ای شب‌رنگ (dark) جایگزین شود.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MaplibreMapController? _mapController;
  bool _cameraFollowsVehicle = true;
  Line? _routeLine; // خط مسیر روی نقشه

  static const String _demoStyleUrl =
      'https://demotiles.maplibre.org/style.json';

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(35.6997, 51.3380), // تهران، میدان آزادی — نمونه، تا GPS برسد
    zoom: 16,
    tilt: 55, // دوربین سه‌بعدی (pitch)
    bearing: 0,
  );

  @override
  Widget build(BuildContext context) {
    // GPS: مجوز + وضعیت روشن/خاموش بودن سرویس
    final readiness = ref.watch(locationReadinessProvider);
    final vehiclePositionAsync = ref.watch(vehiclePositionProvider);
    final selectedVehicle = ref.watch(selectedVehicleProvider);
    final destination = ref.watch(selectedDestinationProvider);
    final activeNav = ref.watch(activeNavigationProvider);

    // دیپ‌لینک ورودی از اپ‌های دیگر (مثل اسنپ) → مقصد را ست کن و دوربین را ببر آنجا
    ref.listen<AsyncValue<DeepLinkDestination>>(deepLinkDestinationProvider, (prev, next) {
      next.whenData((dest) {
        final point = LatLng(dest.lat, dest.lng);
        ref.read(selectedDestinationProvider.notifier).state =
            SelectedDestination(point, label: dest.label);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
        setState(() => _cameraFollowsVehicle = false);
      });
    });

    // پیگیری پیشرفت مسیریابی
    if (activeNav != null) {
      vehiclePositionAsync.whenData((pos) {
        _updateNavigationProgress(pos, activeNav);
      });
    }

    // دنبال‌کردن خودرو با دوربین (حالت Navigation Mode)
    vehiclePositionAsync.whenData((pos) {
      if (_cameraFollowsVehicle && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(pos.lat, pos.lng),
              zoom: 17,
              tilt: 55,
              bearing: pos.headingDeg,
            ),
          ),
          duration: const Duration(milliseconds: 900),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.frameBackground,
      body: Stack(
        children: [
          // ===== نقشه سه‌بعدی آنلاین =====
          Positioned.fill(
            child: MaplibreMap(
              styleString: _demoStyleUrl,
              initialCameraPosition: _initialCamera,
              myLocationEnabled: false, // نقطه‌ی داخلی MapLibre را خاموش می‌کنیم؛ خودمان VehicleMarker داریم
              compassEnabled: false, // کامپس سفارشی خودمان را نمایش می‌دهیم
              onMapCreated: (controller) => _mapController = controller,
              onMapClick: (point, latLng) {
                // ===== مسیریابی از طریق لمس نقشه =====
                ref.read(selectedDestinationProvider.notifier).state =
                    SelectedDestination(latLng);
                setState(() => _cameraFollowsVehicle = false);
              },
              onCameraTrackingDismissed: () => setState(() => _cameraFollowsVehicle = false),
              onStyleLoadedCallback: () {
                // TODO(فاز بعد): لایه‌ی ساختمان‌های سه‌بعدی (fill-extrusion)
                // و ترسیم خط مسیر واقعی پس از اتصال Valhalla.
              },
            ),
          ),

          // ===== مارکر خودرو/پیکان روی نقشه (پیرو GPS واقعی) =====
          vehiclePositionAsync.when(
            data: (pos) => VehicleMarker(
              mapController: _mapController,
              position: LatLng(pos.lat, pos.lng),
              headingDeg: pos.headingDeg,
              vehicle: selectedVehicle,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ===== مارکر مقصد (از لمس نقشه یا دیپ‌لینک) =====
          if (destination != null)
            _DestinationPin(mapController: _mapController, point: destination.point),

          // ===== بنر وضعیت GPS (مجوز رد شده / سرویس خاموش) =====
          readiness.when(
            data: (state) => state == LocationReadiness.ready
                ? const SizedBox.shrink()
                : Positioned(top: 16, left: 24, right: 24, child: _GpsWarningBanner(state: state)),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ===== کارت دستور بعدی (بالای صفحه) — وقتی مقصدی انتخاب نشده صرفاً نمونه‌ی UI است =====
          if (destination == null && activeNav == null)
            const Positioned(top: 16, left: 24, right: 24, child: _InstructionCard()),

          // ===== کارت مسیریابی فعال (دستور پیچ‌به‌پیچ) =====
          if (activeNav != null)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: _ActiveNavigationCard(navigation: activeNav),
            ),

          // ===== کارت مقصدِ انتخاب‌شده (وقتی کاربر روی نقشه لمس کرده یا دیپ‌لینک آمده) =====
          if (destination != null && activeNav == null)
            Positioned(
              bottom: 130,
              left: 16,
              right: 16,
              child: _DestinationCard(
                destination: destination,
                onClear: () {
                  ref.read(selectedDestinationProvider.notifier).state = null;
                  _clearRoute();
                },
                onStartNavigation: () => _startNavigation(),
              ),
            ),

          // ===== کامپس =====
          Positioned(
            top: 190,
            right: 16,
            child: _Compass(headingDeg: vehiclePositionAsync.valueOrNull?.headingDeg ?? 0),
          ),

          // ===== دکمه موقعیت من =====
          Positioned(
            bottom: destination != null || activeNav != null ? 250 : 130,
            right: 16,
            child: _RoundIconButton(
              icon: Icons.my_location_rounded,
              onTap: () {
                setState(() => _cameraFollowsVehicle = true);
                final pos = vehiclePositionAsync.valueOrNull;
                if (pos != null) {
                  _mapController?.animateCamera(CameraUpdate.newCameraPosition(
                    CameraPosition(target: LatLng(pos.lat, pos.lng), zoom: 17, tilt: 55, bearing: pos.headingDeg),
                  ));
                } else {
                  _mapController?.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
                }
              },
            ),
          ),

          // ===== دکمه توقف مسیریابی =====
          if (activeNav != null)
            Positioned(
              bottom: 130,
              left: 16,
              right: 16,
              child: _RoundButton(
                label: 'پایان مسیریابی',
                color: Colors.red,
                onTap: () => _stopNavigation(),
              ),
            ),

          // ===== خوشه سرعت (سرعت واقعی از GPS) =====
          Positioned(
            bottom: 90,
            left: 16,
            child: _SpeedCluster(speedKmh: vehiclePositionAsync.valueOrNull?.speedKmh ?? 0),
          ),

          // ===== ناوبری پایین (تم سبز، چون صفحه اصلی است) =====
          const BottomNav(currentPage: NavKey.home, isHomePage: true),
        ],
      ),
    );
  }

  /// شروع مسیریابی
  Future<void> _startNavigation() async {
    final destination = ref.read(selectedDestinationProvider);
    final vehiclePosition = ref.read(vehiclePositionProvider).value;

    if (destination == null || vehiclePosition == null) return;

    // محاسبه مسیر
    final routingService = ref.read(routingServiceProvider);
    final route = await routingService.calculateRoute(
      origin: LatLng(vehiclePosition.lat, vehiclePosition.lng),
      destination: destination.point,
    );

    if (route == null) {
      // نمایش پیام خطا
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در محاسبه مسیر. لطفاً دوباره تلاش کنید.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // رسم خط مسیر روی نقشه
    await _drawRoute(route.geometry);

    // فعال‌سازی مسیریابی
    ref.read(activeNavigationProvider.notifier).setNavigation(
      ActiveNavigation(
        route: route,
        state: NavigationState.navigating,
        remainingDistanceKm: route.distanceKm,
      ),
    );

    // فعال کردن حالت دنبال‌کردن خودرو
    setState(() => _cameraFollowsVehicle = true);
  }

  /// رسم خط مسیر روی نقشه
  Future<void> _drawRoute(List<LatLng> geometry) async {
    if (_mapController == null) return;

    // حذف خط قبلی در صورت وجود
    if (_routeLine != null) {
      await _mapController!.removeLine(_routeLine!);
    }

    // رسم خط جدید
    _routeLine = await _mapController!.addLine(
      LineOptions(
        geometry: geometry,
        lineColor: '#10D15C', // رنگ سبز اصلی اپ
        lineWidth: 6.0,
        lineOpacity: 0.85,
      ),
    );
  }

  /// پاک کردن خط مسیر
  Future<void> _clearRoute() async {
    if (_mapController != null && _routeLine != null) {
      await _mapController!.removeLine(_routeLine!);
      _routeLine = null;
    }
  }

  /// توقف مسیریابی
  void _stopNavigation() {
    ref.read(activeNavigationProvider.notifier).clear();
    ref.read(selectedDestinationProvider.notifier).state = null;
    _clearRoute();
    setState(() {});
  }

  /// به‌روزرسانی پیشرفت مسیریابی
  void _updateNavigationProgress(VehiclePosition pos, ActiveNavigation nav) {
    // محاسبه فاصله تا نزدیک‌ترین نقطه دستور بعدی
    final currentLoc = LatLng(pos.lat, pos.lng);
    
    // پیدا کردن دستور فعلی بر اساس فاصله
    int nearestInstructionIndex = nav.currentInstructionIndex;
    double minDistance = double.infinity;
    
    for (int i = nav.currentInstructionIndex; i < nav.route.instructions.length; i++) {
      final instruction = nav.route.instructions[i];
      final distance = _calculateDistance(currentLoc, instruction.location);
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestInstructionIndex = i;
      }
      
      // اگر از این دستور عبور کردیم، به دستور بعدی برویم
      if (distance < 30) { // 30 متر آستانه
        nearestInstructionIndex = math.min(i + 1, nav.route.instructions.length - 1);
      }
    }

    // محاسبه فاصله باقیمانده تقریبی
    double remainingDistance = 0;
    for (int i = nearestInstructionIndex; i < nav.route.instructions.length; i++) {
      remainingDistance += nav.route.instructions[i].distanceMeters;
    }

    // به‌روزرسانی وضعیت
    if (nearestInstructionIndex != nav.currentInstructionIndex || 
        (remainingDistance / 1000 - nav.remainingDistanceKm).abs() > 0.1) {
      ref.read(activeNavigationProvider.notifier).updateProgress(
        nearestInstructionIndex,
        remainingDistance / 1000,
      );
    }

    // بررسی رسیدن به مقصد
    if (minDistance < 20 && nearestInstructionIndex >= nav.route.instructions.length - 1) {
      _onArrived();
    }
  }

  /// محاسبه فاصله بین دو نقطه (متر) - فرمول Haversine
  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000.0; // متر
    
    final lat1 = degToRad(point1.latitude);
    final lat2 = degToRad(point2.latitude);
    final dLat = degToRad(point2.latitude - point1.latitude);
    final dLng = degToRad(point2.longitude - point1.longitude);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// رسیدن به مقصد
  void _onArrived() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 به مقصد رسیدید!'),
          backgroundColor: Color(0xFF10D15C),
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    // توقف خودکار مسیریابی بعد از 3 ثانیه
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _stopNavigation();
      }
    });
  }

}

class _GpsWarningBanner extends StatelessWidget {
  final LocationReadiness state;
  const _GpsWarningBanner({required this.state});

  String get _message {
    switch (state) {
      case LocationReadiness.serviceDisabled:
        return 'GPS دستگاه خاموش است. لطفاً آن را روشن کنید.';
      case LocationReadiness.permissionDenied:
        return 'برای ناوبری به مجوز موقعیت مکانی نیاز است.';
      case LocationReadiness.permissionDeniedForever:
        return 'مجوز موقعیت مکانی رد شده. از تنظیمات گوشی فعالش کنید.';
      case LocationReadiness.ready:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_message, style: const TextStyle(color: Colors.white, fontSize: 12))),
        ],
      ),
    );
  }
}

class _DestinationPin extends StatelessWidget {
  final MaplibreMapController? mapController;
  final LatLng point;
  const _DestinationPin({required this.mapController, required this.point});

  @override
  Widget build(BuildContext context) {
    if (mapController == null) return const SizedBox.shrink();
    return FutureBuilder<math.Point<double>>(
      future: mapController!.toScreenLocation(point),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final s = snapshot.data!;
        return Positioned(
          left: s.x - 16,
          top: s.y - 32,
          child: const IgnorePointer(
            child: Icon(Icons.location_on_rounded, color: AppColors.subAccentB, size: 32),
          ),
        );
      },
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final SelectedDestination destination;
  final VoidCallback onClear;
  final VoidCallback onStartNavigation;
  const _DestinationCard({
    required this.destination,
    required this.onClear,
    required this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.subAccentB),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: onClear),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  destination.label ?? 'مقصد انتخاب‌شده',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${destination.point.latitude.toStringAsFixed(5)}, ${destination.point.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppColors.subAccentGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: GestureDetector(
              onTap: onStartNavigation,
              child: const Text(
                'شروع مسیریابی',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(.06)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.touch_app_rounded, color: AppColors.homeAccent, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'برای مسیریابی، روی نقشه لمس کنید یا از جستجو استفاده کنید.',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Compass extends StatelessWidget {
  final double headingDeg;
  const _Compass({required this.headingDeg});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(.4),
        border: Border.all(color: Colors.white.withOpacity(.15)),
      ),
      child: Transform.rotate(
        angle: -headingDeg * 3.1415926535 / 180,
        child: const Center(
          child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.homeAccentDark,
          border: Border.all(color: Colors.white.withOpacity(.08)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14)],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _SpeedCluster extends StatelessWidget {
  final double speedKmh;
  const _SpeedCluster({required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 90,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: _SpeedDial(value: speedKmh.round().toString(), size: 90),
          ),
          const Positioned(
            left: 55,
            bottom: 25,
            child: _SpeedDial(value: '60', size: 56, isLimitSign: true),
          ),
        ],
      ),
    );
  }
}

class _SpeedDial extends StatelessWidget {
  final String value;
  final double size;
  final bool isLimitSign;

  const _SpeedDial({required this.value, required this.size, this.isLimitSign = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLimitSign ? Colors.white : const Color(0xFF1A1E24),
        border: isLimitSign ? Border.all(color: Colors.red, width: 4) : null,
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: isLimitSign ? Colors.black : Colors.white,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!isLimitSign)
              const Text('km/h', style: TextStyle(color: Color(0xFFDFE3E6), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}



/// کارت مسیریابی فعال - نمایش دستور پیچ‌به‌پیچ
class _ActiveNavigationCard extends StatelessWidget {
  final ActiveNavigation navigation;
  const _ActiveNavigationCard({required this.navigation});

  @override
  Widget build(BuildContext context) {
    final instruction = navigation.currentInstruction;
    final remainingKm = navigation.remainingDistanceKm;
    final remainingMin = (navigation.route.durationMin * (remainingKm / navigation.route.distanceKm)).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.homeAccent.withOpacity(.5), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // دستور فعلی
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.homeAccent.withOpacity(.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getInstructionIcon(instruction.type),
                  color: AppColors.homeAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  instruction.text,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // اطلاعات مسیر
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoChip(
                icon: Icons.speed_rounded,
                label: '${remainingMin} دقیقه',
                color: AppColors.subAccentA,
              ),
              _InfoChip(
                icon: Icons.straighten_rounded,
                label: '${remainingKm.toStringAsFixed(1)} کیلومتر',
                color: AppColors.subAccentB,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getInstructionIcon(String type) {
    switch (type) {
      case 'turn':
        return Icons.turn_right_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      case 'depart':
        return Icons.navigation_rounded;
      case 'merge':
        return Icons.merge_rounded;
      case 'roundabout':
      case 'rotary':
        return Icons.roundabout_right_rounded;
      default:
        return Icons.arrow_upward_rounded;
    }
  }
}

/// چیپ اطلاعات کوچک
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );
  }
}

/// دکمه دایره‌ای بزرگ با برچسب
class _RoundButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RoundButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(.85),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: color.withOpacity(.4), blurRadius: 20),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
