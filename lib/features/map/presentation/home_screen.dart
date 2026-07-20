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
import 'dart:async';
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
  MapLibreMapController? _mapController;
  bool _cameraFollowsVehicle = true;
  Line? _routeLine; // خط مسیر روی نقشه

  // استایل نقشه‌ی تیره‌ی حرفه‌ای از OpenFreeMap (رایگان، بدون نیاز به API Key،
  // بر پایه‌ی داده‌های OpenStreetMap با خیابان‌ها و ساختمان‌های سه‌بعدی).
  static const String _demoStyleUrl =
      'https://tiles.openfreemap.org/styles/dark';

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
            // این Listener فقط برای تشخیص «لمس واقعی کاربر روی نقشه» است (پن/زوم/چرخش)؛
            // با اولین لمس، حالت دنبال‌کردن دوربین از خودرو خاموش می‌شود تا کاربر
            // بتواند آزادانه نقشه را جابجا کند. مارکر خودرو مستقل از این، همیشه با
            // GPS واقعی به‌روزرسانی می‌شود و فقط دوربین است که دیگر دنبالش نمی‌کند.
            child: Listener(
              onPointerDown: (_) {
                if (_cameraFollowsVehicle) {
                  setState(() => _cameraFollowsVehicle = false);
                }
              },
              child: MapLibreMap(
                styleString: _demoStyleUrl,
                initialCameraPosition: _initialCamera,
                myLocationEnabled: false, // نقطه‌ی داخلی MapLibre را خاموش می‌کنیم؛ خودمان VehicleMarker داریم
                compassEnabled: false, // کامپس سفارشی خودمان را نمایش می‌دهیم
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: true,
                zoomGesturesEnabled: true,
                onMapCreated: _onMapCreated,
                // انتخاب مقصد با لمس طولانی (نه لمس کوتاه)، تا لمس کوتاه برای
                // جابجایی/تعامل عادی با نقشه آزاد بماند
                onMapLongClick: (point, latLng) {
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
          ),

          // ===== مارکر خودرو/پیکان روی نقشه (پیرو GPS واقعی) =====
          // همیشه نمایش داده می‌شود؛ تا وقتی GPS قفل نشده روی موقعیت اولیه نشان داده می‌شود
          Builder(
            builder: (_) {
              final pos = vehiclePositionAsync.valueOrNull;
              final markerPos =
                  pos != null ? LatLng(pos.lat, pos.lng) : _initialCamera.target;
              return VehicleMarker(
                mapController: _mapController,
                position: markerPos,
                headingDeg: pos?.headingDeg ?? 0,
                vehicle: selectedVehicle,
              );
            },
          ),

          // ===== مارکر مقصد (از لمس نقشه یا دیپ‌لینک) =====
          if (destination != null)
            _DestinationPin(mapController: _mapController, point: destination.point),

          // ===== بنر وضعیت GPS (مجوز رد شده / سرویس خاموش) =====
          // نکته مهم: از MediaQuery.padding.top استفاده می‌کنیم تا زیر ناچ/نوار
          // وضعیت گوشی پنهان نشود (قبلاً top ثابت 16 بود که روی گوشی‌های با
          // ناچ/Dynamic Island باعث می‌شد بنر زیر ساعت/دوربین برود). همچنین اگر
          // کارت مسیریابی فعال هم بالای صفحه باز باشد، بنر پایین‌تر از آن
          // می‌نشیند تا رویش نیفتد. AnimatedSwitcher باعث می‌شود بنر با
          // فید+اسلاید نرم ظاهر/محو شود، نه به‌صورت ناگهانی (پویا/داینامیک).
          Positioned(
            top: MediaQuery.of(context).padding.top + (activeNav != null ? 118 : 12),
            left: 24,
            right: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: readiness.when(
                data: (state) => state == LocationReadiness.ready
                    ? const SizedBox.shrink(key: ValueKey('gps-ok'))
                    : _GpsWarningBanner(key: ValueKey('gps-$state'), state: state),
                loading: () => const SizedBox.shrink(key: ValueKey('gps-loading')),
                error: (_, __) => const SizedBox.shrink(key: ValueKey('gps-error')),
              ),
            ),
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
          // فاصله‌ی اضافه از پایین فقط وقتی لازم است که کارت مقصدِ انتخاب‌شده
          // واقعاً نمایش داده شود (چون دیگر دکمه‌ی جداگانه‌ی «پایان مسیریابی»
          // در پایین صفحه وجود ندارد).
          Positioned(
            bottom: destination != null && activeNav == null ? 250 : 130,
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

          // نکته: دکمه‌ی «پایان مسیریابی» جداگانه در پایین صفحه حذف شد؛ طبق
          // طرح مرجع، بستن مسیریابی از طریق ضربدر گوشه‌ی کارت بالای صفحه
          // (_ActiveNavigationCard) انجام می‌شود.

          // ===== خوشه سرعت (سرعت واقعی از GPS) =====
          Positioned(
            bottom: 90,
            left: 16,
            child: _SpeedCluster(
              speedKmh: vehiclePositionAsync.valueOrNull?.speedKmh ?? 0,
              speedLimitKmh: null, // فعلاً منبع داده‌ی محدودیت سرعت متصل نشده؛ وقتی وصل شد این مقدار را بدهید تا تابلو نمایش داده شود
            ),
          ),

          // ===== ناوبری پایین (تم سبز، چون صفحه اصلی است) =====
          const BottomNav(currentPage: NavKey.home, isHomePage: true),

          // ===== کارت مسیریابی فعال (دستور پیچ‌به‌پیچ) — بالاترین z-index، بالای همه‌ی پنجره‌ها =====
          if (activeNav != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _ActiveNavigationCard(
                navigation: activeNav,
                onClose: () => _stopNavigation(),
              ),
            ),
        ],
      ),
    );
  }

  /// راه‌اندازی کنترلر نقشه
  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    // با هر حرکت دوربین (زوم/جابجایی/چرخش) مارکرهای Overlay بازموقعیت‌دهی شوند
    controller.addListener(_onCameraMoved);
    // rebuild تا mapController به VehicleMarker/DestinationPin برسد و پوینتر ظاهر شود
    if (mounted) setState(() {});
  }

  /// با حرکت دوربین، مختصات صفحه‌ی مارکرها را به‌روزرسانی می‌کنیم
  void _onCameraMoved() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mapController?.removeListener(_onCameraMoved);
    super.dispose();
  }

  /// شروع مسیریابی
  Future<void> _startNavigation() async {
    final destination = ref.read(selectedDestinationProvider);
    final vehiclePosition = ref.read(vehiclePositionProvider).value;

    if (destination == null || vehiclePosition == null) return;

    // محاسبه مسیر
    final routingService = ref.read(routingServiceProvider);
    final origin = LatLng(vehiclePosition.lat, vehiclePosition.lng);
    var route = await routingService.calculateRoute(
      origin: origin,
      destination: destination.point,
    );

    // اگر سرور مسیریابی در دسترس نبود (حالت آفلاین) → مسیر تقریبی خط مستقیم
    if (route == null) {
      route = routingService.straightLineFallback(origin, destination.point);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اتصال به سرور مسیریابی برقرار نشد؛ مسیر تقریبی آفلاین نمایش داده می‌شود.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

    // فاصله تا پیچ بعدی (موقعیت دستور فعلی)
    final nextLoc = nav.route.instructions[nearestInstructionIndex].location;
    final distToNext = _calculateDistance(currentLoc, nextLoc);

    // به‌روزرسانی وضعیت (زنده — تا فاصله‌ی پیچ بعدی مدام کم شود)
    ref.read(activeNavigationProvider.notifier).updateProgress(
      nearestInstructionIndex,
      remainingDistance / 1000,
      distanceToNextManeuverM: distToNext,
    );

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
  const _GpsWarningBanner({super.key, required this.state});

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
        color: Colors.red.withOpacity(.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.15)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6)),
        ],
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

class _DestinationPin extends StatefulWidget {
  final MapLibreMapController? mapController;
  final LatLng point;
  const _DestinationPin({required this.mapController, required this.point});

  @override
  State<_DestinationPin> createState() => _DestinationPinState();
}

class _DestinationPinState extends State<_DestinationPin> {
  math.Point<num>? _screen;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _update();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _update());
  }

  @override
  void didUpdateWidget(covariant _DestinationPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _update() async {
    final controller = widget.mapController;
    if (controller == null) return;
    try {
      final s = await controller.toScreenLocation(widget.point);
      if (mounted) setState(() => _screen = s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = _screen;
    if (s == null) return const SizedBox.shrink();
    return Positioned(
      left: s.x.toDouble() - 16,
      top: s.y.toDouble() - 32,
      child: const IgnorePointer(
        child: Icon(Icons.location_on_rounded, color: AppColors.subAccentB, size: 32),
      ),
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // خطوط جهت (شمال/جنوب/شرق/غرب) — همراه با چرخش دستگاه می‌چرخند
          Transform.rotate(
            angle: -headingDeg * 3.1415926535 / 180,
            child: CustomPaint(size: const Size(56, 56), painter: _CompassTicksPainter()),
          ),
          // عقربه‌ی اصلی قطب‌نما (قرمز = شمال، خاکستری = جنوب)
          Transform.rotate(
            angle: -headingDeg * 3.1415926535 / 180,
            child: CustomPaint(size: const Size(30, 30), painter: _CompassNeedlePainter()),
          ),
          // نقطه‌ی مرکزی
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// عقربه‌ی کلاسیک قطب‌نما: دو مثلث به‌هم‌چسبیده، نوک قرمز به‌سمت شمال
class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tip = size.height / 2 - 2;
    final tail = size.height / 2 - 2;
    const halfWidth = 4.0;

    final northPaint = Paint()..color = const Color(0xFFE53E3E);
    final southPaint = Paint()..color = const Color(0xFFB8C0CC);

    final northPath = Path()
      ..moveTo(center.dx, center.dy - tip)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..close();

    final southPath = Path()
      ..moveTo(center.dx, center.dy + tail)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..close();

    canvas.drawPath(northPath, northPaint);
    canvas.drawPath(southPath, southPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// چهار خط کوتاه برای جهت‌های اصلی دور قطب‌نما، به‌همراه حرف N روی شمال
class _CompassTicksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(.6)
      ..strokeWidth = 1.5;

    for (var i = 0; i < 4; i++) {
      final angle = (i * 90) * 3.1415926535 / 180;
      final outer = Offset(
        center.dx + radius * math.sin(angle),
        center.dy - radius * math.cos(angle),
      );
      final inner = Offset(
        center.dx + (radius - 5) * math.sin(angle),
        center.dy - (radius - 5) * math.cos(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(color: Color(0xFFE53E3E), fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - radius - textPainter.height + 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

/// معادل دقیق .speed-cluster در css: سرعت‌سنج همیشه نمایش داده می‌شود؛
/// تابلوی محدودیت سرعت فقط وقتی مقدار واقعی موجود باشد نشان داده می‌شود.
class _SpeedCluster extends StatelessWidget {
  final double speedKmh;
  final int? speedLimitKmh;
  const _SpeedCluster({required this.speedKmh, this.speedLimitKmh});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // سرعت‌سنج اصلی — همیشه نمایش داده می‌شود
          Positioned(
            left: 0,
            bottom: 0,
            child: _SpeedometerDial(value: speedKmh.round().toString()),
          ),
          // تابلوی محدودیت سرعت — فقط اگر مقدار موجود باشد
          if (speedLimitKmh != null)
            Positioned(
              left: 66,
              bottom: 34,
              child: _SpeedLimitSign(value: speedLimitKmh!.toString()),
            ),
        ],
      ),
    );
  }
}

class _SpeedometerDial extends StatelessWidget {
  final String value;
  const _SpeedometerDial({required this.value});

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/speedometer.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2))],
                ),
              ),
              const Text(
                'km/h',
                style: TextStyle(
                  color: Color(0xFFDFE3E6),
                  fontSize: 11,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2))],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedLimitSign extends StatelessWidget {
  final String value;
  const _SpeedLimitSign({required this.value});

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/speed-limit.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2))],
            ),
          ),
        ],
      ),
    );
  }
}



/// کارت مسیریابی فعال - نمایش دستور پیچ‌به‌پیچ
///
/// طراحی مطابق عکس مرجع کاربر: کارت آبی‌سرمه‌ای تیره با آیکون پیچ سبز درخشان
/// سمت چپ، فاصله+دستور فعلی سمت راست، یک خط جداکننده، و ردیف پایین شامل
/// «زمان رسیدن / مسافت مانده / زمان باقی‌مانده» به‌همراه دکمه‌ی ضربدر گوشه‌ی
/// کارت برای پایان مسیریابی (دیگر دکمه‌ی جداگانه‌ای در پایین صفحه نیست).
class _ActiveNavigationCard extends StatelessWidget {
  final ActiveNavigation navigation;
  final VoidCallback onClose;
  const _ActiveNavigationCard({required this.navigation, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final instruction = navigation.currentInstruction;
    final remainingKm = navigation.remainingDistanceKm;
    // اگر مسافت کل مسیر صفر باشد (مثلاً مقصد دقیقاً روی موقعیت فعلی انتخاب شده)،
    // تقسیم بر صفر باعث NaN و کرش .round() می‌شود؛ در این حالت ۰ دقیقه نمایش می‌دهیم.
    final remainingMin = navigation.route.distanceKm > 0
        ? (navigation.route.durationMin * (remainingKm / navigation.route.distanceKm)).round()
        : 0;
    final dNext = navigation.distanceToNextManeuverM;
    final nextText = dNext >= 1000
        ? '${(dNext / 1000).toStringAsFixed(1)} کیلومتر'
        : '${dNext.round()} متر';

    // زمان تخمینی رسیدن (ساعت:دقیقه) بر اساس زمان باقی‌مانده
    final eta = DateTime.now().add(Duration(minutes: remainingMin));
    final etaText =
        '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        // آبی سرمه‌ای تیره‌ی نیمه‌شفاف، دقیقاً حس‌وحال عکس مرجع
        color: const Color(0xF0182541),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 26, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== ردیف بالا: آیکون پیچ + فاصله/دستور فعلی =====
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  _getInstructionIcon(instruction.type),
                  color: AppColors.homeAccent,
                  size: 42,
                  shadows: [
                    Shadow(color: AppColors.homeAccent.withOpacity(.65), blurRadius: 18),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (dNext > 0)
                      Text(
                        nextText,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.55),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      instruction.text,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withOpacity(.12), height: 1),
          const SizedBox(height: 8),
          // ===== ردیف پایین: زمان رسیدن / مسافت مانده / زمان باقی‌مانده + ضربدر =====
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavStat(label: 'زمان رسیدن', value: etaText),
                    _NavStat(label: 'مسافت مانده', value: '${remainingKm.toStringAsFixed(1)} کیلومتر'),
                    _NavStat(label: 'زمان باقی‌مانده', value: '$remainingMin دقیقه'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.08),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                ),
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

/// یک آیتم آمار کوچک در ردیف پایین کارت مسیریابی (برچسب + مقدار)
class _NavStat extends StatelessWidget {
  final String label;
  final String value;
  const _NavStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 10),
          ),
        ],
      ),
    );
  }
}


