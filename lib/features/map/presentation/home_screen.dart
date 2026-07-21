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
import 'dart:ui';

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

  // نکته (رفع «نقشه خاکستری/خالی می‌ماند»): بارگذاری استایل نقشه به اینترنت
  // نیاز دارد؛ اگر لحظه‌ی باز شدن اپ شبکه قطع/کند باشد، نقشه تا ابد خاکستری
  // می‌ماند بدون این‌که کاربر بفهمد مشکل چیست. این‌ها وضعیت را رصد می‌کنند
  // و بعد از چند ثانیه یک پیام + دکمه‌ی «تلاش دوباره» نشان می‌دهند.
  bool _styleLoaded = false;
  bool _showMapRetry = false;
  Timer? _mapLoadTimeoutTimer;
  int _mapReloadKey = 0;

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

  // نقطه ثابت روی صفحه برای پیکان در حالت navigation (وسط، کمی پایین‌تر)
  late Offset _fixedArrowAnchor;

  void _startMapLoadWatchdog() {
    _mapLoadTimeoutTimer?.cancel();
    _showMapRetry = false;
    _mapLoadTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && !_styleLoaded) {
        setState(() => _showMapRetry = true);
      }
    });
  }

  void _retryMapLoad() {
    setState(() {
      _styleLoaded = false;
      _showMapRetry = false;
      _mapReloadKey++; // با تغییر key ویجت MapLibreMap کامل از نو ساخته می‌شود
    });
    _startMapLoadWatchdog();
  }

  @override
  void initState() {
    super.initState();
    _startMapLoadWatchdog();
    // محاسبه نقطه ثابت برای پیکان (وسط افقی، کمی پایین‌تر از مرکز عمودی)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenSize = MediaQuery.of(context).size;
        setState(() {
          _fixedArrowAnchor = Offset(
            screenSize.width / 2,
            screenSize.height / 2 + 60,
          );
        });
      }
    });
  }

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

    // نکته‌ی مهم (رفع باگ جدی «کرش هنگام مسیریابی فعال»):
    // نسخه‌ی قبلی این بخش از vehiclePositionAsync.whenData(...) مستقیماً
    // داخل build() استفاده می‌کرد تا هم دوربین را دنبال خودرو ببرد و هم
    // ref.read(activeNavigationProvider.notifier).updateProgress(...) را صدا
    // بزند. چون این دومی state یک Provider دیگر را همان لحظه، وسط ساخته‌شدن
    // درخت ویجت، تغییر می‌داد، Riverpod خطای معروف
    // «Tried to modify a provider while the widget tree was building» را پرتاب
    // می‌کرد — دقیقاً زمانی که مسیریابی فعال بود (یعنی وقتی کاربر بیشتر از
    // همه به پایداری اپ نیاز دارد). راه‌حل درست، جابه‌جایی این اثرجانبی‌ها از
    // build() به ref.listen است — که Riverpod آن را بعد از پایان build، در
    // زمان امن اجرا می‌کند.
    ref.listen<AsyncValue<VehiclePosition>>(vehiclePositionProvider, (prev, next) {
      next.whenData((pos) {
        if (activeNav != null) {
          _updateNavigationProgress(pos, activeNav);
        }
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
                key: ValueKey('map-$_mapReloadKey'),
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
                  _mapLoadTimeoutTimer?.cancel();
                  if (mounted) setState(() { _styleLoaded = true; _showMapRetry = false; });
                  // TODO(فاز بعد): لایه‌ی ساختمان‌های سه‌بعدی (fill-extrusion)
                  // و ترسیم خط مسیر واقعی پس از اتصال Valhalla.
                },
              ),
            ),
          ),

          // ===== وضعیت «نقشه دیر لود شده» =====
          // نکته‌ی مهم (رفع باگ «کل صفحه محو/خراب می‌شود»): نسخه‌ی قبلی این
          // بخش یک Positioned.fill با پرده‌ی سیاه نیمه‌شفاف روی کل نقشه
          // می‌کشید. چون سرور استایل (openfreemap) گاهی کند است و
          // onStyleLoadedCallback همیشه هم به‌موقع صدا زده نمی‌شود، این پرده
          // با وجود این‌که نقشه واقعاً داشت لود می‌شد، زیاد ظاهر می‌شد و کل
          // برنامه «خراب/محو» به‌نظر می‌رسید. حالا به‌جای پوشاندن کل نقشه، فقط
          // یک بج شیشه‌ای کوچک و غیرمسدودکننده بالای صفحه (کنار بنر GPS)
          // نشان می‌دهیم که نقشه زیرش کاملاً قابل دیدن و استفاده بماند، و
          // زمان انتظار قبل از نمایش آن هم از ۹ به ۲۰ ثانیه افزایش یافت.
          if (_showMapRetry && !_styleLoaded)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  (activeNav != null
                      ? 118
                      : (destination != null
                          ? 108
                          : (readiness.valueOrNull != null &&
                                  readiness.valueOrNull != LocationReadiness.ready
                              ? 64
                              : 12))),
              left: 24,
              right: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xCC14171F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'اتصال نقشه کند است…',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        GestureDetector(
                          onTap: _retryMapLoad,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.subAccentGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'تلاش دوباره',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
          // در حالت navigation، پیکان به نقطه‌ی ثابت روی صفحه قفل می‌شود
          // (مثل Google Maps/Waze) تا مشکل toScreenLocation با tilted camera حل شود
          if (destination != null)
            _DestinationPin(
              mapController: _mapController,
              point: destination.point,
              isNavigationMode: activeNav != null,
              fixedAnchor: _fixedArrowAnchor,
            ),

          // ===== بنر وضعیت GPS (مجوز رد شده / سرویس خاموش) =====
          // نکته مهم: از MediaQuery.padding.top استفاده می‌کنیم تا زیر ناچ/نوار
          // وضعیت گوشی پنهان نشود (قبلاً top ثابت 16 بود که روی گوشی‌های با
          // ناچ/Dynamic Island باعث می‌شد بنر زیر ساعت/دوربین برود). همچنین اگر
          // کارت مسیریابی فعال هم بالای صفحه باز باشد، بنر پایین‌تر از آن
          // می‌نشیند تا رویش نیفتد. AnimatedSwitcher باعث می‌شود بنر با
          // فید+اسلاید نرم ظاهر/محو شود، نه به‌صورت ناگهانی (پویا/داینامیک).
          Positioned(
            top: MediaQuery.of(context).padding.top +
                (activeNav != null
                    ? 118
                    : (destination != null ? 108 : 12)),
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
          // قبلاً این کارت پایین صفحه (روی خوشه‌ی سرعت) باز می‌شد؛ طبق درخواست
          // به بالای صفحه منتقل شد، دقیقاً مثل جای کارت مسیریابی فعال، تا هم با
          // بقیه‌ی پنل‌های بالای نقشه هم‌راستا باشد و هم زیر دست/خوشه‌ی سرعت را
          // نپوشاند.
          if (destination != null && activeNav == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
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
          // نکته: کارت مقصدِ انتخاب‌شده دیگر پایین صفحه باز نمی‌شود (به بالا
          // منتقل شد)، پس این دکمه دیگر نیازی به فاصله‌ی اضافه از پایین ندارد.
          Positioned(
            bottom: 130,
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
    _mapLoadTimeoutTimer?.cancel();
    super.dispose();
  }

  /// نکته‌ی مهم (رفع باگ «نوتیفیکیشن‌های پایین صفحه با استایل اپ هم‌خوان
  /// نیستند»): SnackBar پیش‌فرض فلاتر یک نوار تخت و راست‌گوشه (رنگ‌ِ solid
  /// نارنجی/سبز) پایین صفحه می‌کشد که هیچ ربطی به طراحی شیشه‌ای بقیه‌ی اپ
  /// ندارد. این متد به‌جایش یک SnackBar شناور و شیشه‌ای (بلور + حاشیه‌ی
  /// نازک + آیکون گرد گرادیانی) نشان می‌دهد که با بنر GPS/نقشه هم‌استایل است.
  /// 
  /// نکته جدید: margin را تغییر دادیم تا نوتیفیکیشن‌ها زیر کارت Navigation/GPS
  /// قرار بگیرند (نه پایین صفحه روی خوشه سرعت). الآن bottom 180 است (قبل 110).
  void _showGlassNotice(String message, {required IconData icon, required List<Color> colors}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 180),
        padding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xCC14171F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.12)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(color: colors.last.withOpacity(.55), blurRadius: 12)],
                    ),
                    child: Icon(icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final origin = LatLng(vehiclePosition.lat, vehiclePosition.lng);
    var route = await routingService.calculateRoute(
      origin: origin,
      destination: destination.point,
    );

    // اگر سرور مسیریابی در دسترس نبود (حالت آفلاین) → مسیر تقریبی خط مستقیم
    if (route == null) {
      route = routingService.straightLineFallback(origin, destination.point);
      _showGlassNotice(
        'اتصال به سرور مسیریابی برقرار نشد؛ مسیر تقریبی آفلاین نمایش داده می‌شود.',
        icon: Icons.cloud_off_rounded,
        colors: const [Color(0xFFFFB74D), Color(0xFFE5834B)],
      );
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
    _showGlassNotice(
      'به مقصد رسیدید!',
      icon: Icons.flag_rounded,
      colors: const [Color(0xFF3DDC84), Color(0xFF10D15C)],
    );
    
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
    // طراحی شیشه‌ای (glass) هم‌راستا با بقیه‌ی پنل‌های اپ به‌جای نوار قرمز
    // ساده‌ی قبلی: بک‌گراند تیره‌ی نیمه‌شفاف با بلور پشت آن، حاشیه‌ی گرادیانی
    // کهربایی/نارنجی (رنگ هشدار، نه قرمز تهاجمی)، آیکون داخل یک بج گرد
    // گرادیانی، و یک هاله‌ی نرم نارنجی پشت کل پنل.
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1712).withOpacity(.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFB84D).withOpacity(.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8A00).withOpacity(.22),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFB84D), Color(0xFFFF7A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.gps_off_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationPin extends StatefulWidget {
  final MapLibreMapController? mapController;
  final LatLng point;
  final bool isNavigationMode;
  final Offset fixedAnchor;
  
  const _DestinationPin({
    required this.mapController,
    required this.point,
    required this.isNavigationMode,
    required this.fixedAnchor,
  });

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
    // اگر در حالت navigation هستیم، به جای محاسبه toScreenLocation
    // (که با tilted camera اشتباه کار می‌کند)، از نقطه‌ی ثابت استفاده کن
    if (widget.isNavigationMode) {
      // نقطه ثابت — نقشه می‌چرخد/pan می‌شود، پیکان ثابت می‌ماند
      if (mounted) {
        setState(() {
          _screen = math.Point(widget.fixedAnchor.dx, widget.fixedAnchor.dy);
        });
      }
      return;
    }

    // حالت عادی: toScreenLocation استفاده کن
    final controller = widget.mapController;
    if (controller == null) return;
    try {
      final s = await controller.toScreenLocation(widget.point);
      
      // اضافی check: اگر مختصات خارج صفحه باشد (بدون اینکه null باشد)
      // یا منفی باشد، fallback به fixed anchor (این حالت نادر است ولی ممکن)
      if (s == null || s.x < 0 || s.y < 0 || 
          s.x > MediaQuery.of(context).size.width || 
          s.y > MediaQuery.of(context).size.height) {
        return; // پنهان کن
      }
      
      if (mounted) setState(() => _screen = s);
    } catch (_) {
      // در صورت exception، پنهان کن
      if (mounted) setState(() => _screen = null);
    }
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
    // طراحی شیشه‌ای مدرن: بلور پشت کارت + حاشیه‌ی گرادیانی آبی‌بنفش (همان
    // subAccentGradient که در بقیه‌ی اپ برای صفحات غیر از خانه استفاده
    // می‌شود) + دکمه‌ی «شروع» به‌صورت یک نوار کامل پایین کارت به‌جای یک
    // تکمه‌ی کوچک کنار متن، تا در دسترس‌تر و واضح‌تر باشد.
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14171F).withOpacity(.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.subAccentB.withOpacity(.45)),
            boxShadow: [
              BoxShadow(
                color: AppColors.subAccentB.withOpacity(.25),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.subAccentGradient,
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            destination.label ?? 'مقصد انتخاب‌شده',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${destination.point.latitude.toStringAsFixed(5)}, ${destination.point.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: onClear,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onStartNavigation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.subAccentGradient,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'شروع مسیریابی',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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

    for (int i = 0; i < 4; i++) {
      final angle = i * 3.1415926535 / 2;
      final x1 = center.dx + radius * math.sin(angle);
      final y1 = center.dy - radius * math.cos(angle);
      final x2 = center.dx + (radius - 4) * math.sin(angle);
      final y2 = center.dy - (radius - 4) * math.cos(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
    }
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(.4),
          border: Border.all(color: Colors.white.withOpacity(.15)),
        ),
        child: Icon(icon, color: Colors.white70, size: 24),
      ),
    );
  }
}

class _SpeedCluster extends StatelessWidget {
  final double speedKmh;
  final double? speedLimitKmh;
  const _SpeedCluster({required this.speedKmh, required this.speedLimitKmh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(.5),
        border: Border.all(color: Colors.white.withOpacity(.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              speedKmh.toStringAsFixed(0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'km/h',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveNavigationCard extends StatelessWidget {
  final ActiveNavigation navigation;
  final VoidCallback onClose;
  const _ActiveNavigationCard({required this.navigation, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14171F).withOpacity(.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.subAccentB.withOpacity(.45)),
            boxShadow: [
              BoxShadow(
                color: AppColors.subAccentB.withOpacity(.25),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.subAccentGradient,
                      ),
                      child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'مسیریابی فعال',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${navigation.remainingDistanceKm.toStringAsFixed(1)} کیلومتر',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: onClose,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
