import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/permissions/location_permission_flow.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/deep_link/deep_link_service.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/glass_notice.dart';
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
  // نکته: تا وقتی navigation جدید شروع نشده true می‌ماند تا از فراخوانی
  // تکراری _onArrived() در همان سفر جلوگیری شود (وگرنه هر تیک GPS بعد از
  // رسیدن، دوباره نوتیس «به مقصد رسیدید» و تایمر _stopNavigation را صف
  // می‌کرد).
  bool _arrivalHandled = false;
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
          // نکته‌ی مهم (بخش دوم رفع باگ «پیکان دقت ندارد»): موقعیت GPS از
          // LocationService از قبل با EMA هموار شده (هر آپدیت خودش نتیجه‌ی
          // میان‌یابی نرم بین نمونه‌ی قبلی و جدید است)، پس نیازی به یک لایه‌ی
          // انیمیشن ۹۰۰ میلی‌ثانیه‌ای دیگر روی خودِ دوربین نیست. چون
          // GPS معمولاً با فاصله‌ی کمتر از ۹۰۰ میلی‌ثانیه به‌روزرسانی
          // می‌شود، هر آپدیت جدید انیمیشن قبلی را قطع و یک انیمیشن تازه
          // شروع می‌کرد؛ در نتیجه دوربین عملاً هیچ‌وقت واقعاً به target
          // نمی‌رسید و همیشه چند صد میلی‌ثانیه از موقعیت واقعی خودرو عقب
          // بود. چون پیکان (در حالت followsCamera) فرض می‌کند دوربین همین
          // الان دقیقاً روی موقعیت خودرو است، این عقب‌افتادگی مستقیماً به‌صورت
          // «پیکان/نقشه با موقعیت واقعی جاده هم‌خوانی ندارد» دیده می‌شد. مدت
          // انیمیشن به ۲۵۰ میلی‌ثانیه کاهش یافت تا دوربین عملاً بین
          // آپدیت‌های پیاپی GPS به target واقعی برسد، در حالی که هنوز به‌قدر
          // کافی برای جلوگیری از جهش دیداری نرم است.
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(pos.lat, pos.lng),
                zoom: 17,
                tilt: 55,
                bearing: pos.headingDeg,
              ),
            ),
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    });

    // نکته‌ی مهم (بخشی از رفع باگ «دکمه برگشت گوشی کلاً از اپ خارج می‌شود»):
    // صفحه‌ی اصلی ریشه‌ی پشته‌ی ناوبری است، پس به‌طور طبیعی چیزی برای pop
    // کردن ندارد و دکمه‌ی برگشت گوشی طبق رفتار استاندارد اندروید (دقیقاً مثل
    // گوگل‌مپس/ویز روی صفحه‌ی اصلی‌شان) اپ را می‌بندد. اما اگر کاربر یک مقصد
    // انتخاب کرده یا ناوبری فعال است، این حالت‌ها از نظر کاربر «یک صفحه/یک
    // مرحله» به‌حساب می‌آیند؛ پس با PopScope اول این‌ها را می‌بندیم (یک مرحله
    // واقعی به عقب) و فقط وقتی هیچ‌کدام باز نیست، اجازه می‌دهیم برگشت واقعی
    // (خروج از اپ) اتفاق بیفتد.
    final canPopHome = destination == null && activeNav == null;

    return PopScope(
      canPop: canPopHome,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (activeNav != null) {
          _stopNavigation();
        } else if (destination != null) {
          ref.read(selectedDestinationProvider.notifier).state = null;
        }
      },
      child: Scaffold(
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
              onPointerDown: (_) => _takeManualCameraControl(),
              child: MapLibreMap(
                key: ValueKey('map-$_mapReloadKey'),
                styleString: _demoStyleUrl,
                initialCameraPosition: _initialCamera,
                myLocationEnabled: false, // نقطه‌ی داخلی MapLibre را خاموش می‌کنیم؛ خودمان VehicleMarker داریم
                compassEnabled: false, // کامپس سفارشی خودمان را نمایش می‌دهیم
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                // نکته‌ی مهم (ادامه‌ی رفع باگ «پیکان موقع اسکرول غیب می‌شود»):
                // _takeManualCameraControl() دوربین را به tilt:0 برمی‌گرداند
                // چون در حالت followsCamera=false، VehicleMarker از
                // toScreenLocation() استفاده می‌کند که با دوربین tilt‌دار
                // مختصات نادرست/خارج از صفحه می‌دهد (توضیح کامل در همان تابع).
                // اما تا امروز خودِ ژست دو-انگشتی tilt همیشه فعال بود، یعنی
                // کاربر می‌توانست وسط همان اسکرول (مثلاً با یک لمس تصادفی
                // دوانگشتی هنگام pan/zoom هم‌زمان) دوباره دوربین را کج کند و
                // دقیقاً همان باگ را برگرداند. الان ژست tilt فقط وقتی دوربین
                // در حالت دنبال‌کردن خودرو است فعال است (جایی که اصلاً به
                // toScreenLocation نیازی نیست)؛ در حالت پن دستی خاموش است تا
                // نقشه صاف بماند و مارکر همیشه درست/قابل‌مشاهده بماند.
                tiltGesturesEnabled: _cameraFollowsVehicle,
                zoomGesturesEnabled: true,
                onMapCreated: _onMapCreated,
                // انتخاب مقصد با لمس طولانی (نه لمس کوتاه)، تا لمس کوتاه برای
                // جابجایی/تعامل عادی با نقشه آزاد بماند
                onMapLongClick: (point, latLng) {
                  ref.read(selectedDestinationProvider.notifier).state =
                      SelectedDestination(latLng);
                  _takeManualCameraControl();
                },
                onCameraTrackingDismissed: _takeManualCameraControl,
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
              top: MediaQuery.of(context).padding.top + 5 +
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
                followsCamera: _cameraFollowsVehicle,
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
            top: MediaQuery.of(context).padding.top + 5 +
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

  /// نکته‌ی مهم (رفع باگ «جای نوتیف‌ها درست نیست»): این متد قبلاً کد کامل
  /// SnackBar شیشه‌ای را همین‌جا تکرار می‌کرد و margin پایینش عدد ثابت ۱۱۰
  /// بود که روی دستگاه‌های مختلف (safe-area متفاوت) همیشه دقیق بالای منوی
  /// پایین نمی‌نشست. حالا از `showGlassNotice` مشترک استفاده می‌کند که
  /// margin را بر اساس ارتفاع واقعی منو + safe-area دستگاه حساب می‌کند.
  void _showGlassNotice(
    String message, {
    required IconData icon,
    required List<Color> colors,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    showGlassNotice(context, message, icon: icon, colors: colors, duration: duration);
  }

  /// شروع مسیریابی
  Future<void> _startNavigation() async {
    final destination = ref.read(selectedDestinationProvider);
    final vehiclePosition = ref.read(vehiclePositionProvider).value;

    if (destination == null || vehiclePosition == null) return;
    _arrivalHandled = false;

    // محاسبه مسیر
    final routingService = ref.read(routingServiceProvider);
    final origin = LatLng(vehiclePosition.lat, vehiclePosition.lng);
    var route = await routingService.calculateRoute(
      origin: origin,
      destination: destination.point,
    );

    // اگر سرور مسیریابی آنلاین در دسترس نبود، قبل از افتادن به مسیر تقریبی
    // خط‌مستقیم، اول مسیریابی آفلاین را امتحان کن (اگر گراف استان پوشش‌دهنده
    // را قبلاً از صفحه‌ی «تنظیمات نقشه» دانلود کرده باشد). این دقیقاً همان
    // وعده‌ای است که آن صفحه به کاربر می‌دهد: «نقشه را دانلود کنید تا بدون
    // اینترنت هم مسیریابی داشته باشید».
    String? offlineFailReason;
    if (route == null) {
      final graphStore = ref.read(offlineGraphStoreProvider);
      final province = graphStore.provinceContaining(origin.latitude, origin.longitude);
      if (province != null) {
        final graph = await graphStore.loadProvince(province.id);
        if (graph != null) {
          final offlineService = ref.read(offlineRoutingServiceProvider);
          route = offlineService.calculateRoute(
            graph: graph,
            origin: origin,
            destination: destination.point,
          );
          offlineFailReason = offlineService.lastError;
        }
      }
    }

    // اگر مسیریابی آفلاین هم ممکن نبود (گراف دانلود نشده یا مسیر پیدا نشد)
    // → مسیر تقریبی خط مستقیم، آخرین fallback
    if (route == null) {
      route = routingService.straightLineFallback(origin, destination.point);
      // نکته‌ی مهم: چون امکان گرفتن لاگ از گوشی نیست، دلیل دقیق شکست
      // (کد HTTP / تایم‌اوت / متن خطا) را همین‌جا روی صفحه نشان می‌دهیم تا
      // بدون هیچ ابزار جانبی، علت واقعی قابل‌خواندن باشد.
      final reason = offlineFailReason ?? routingService.lastError;
      _showGlassNotice(
        reason == null
            ? 'اتصال به سرور مسیریابی برقرار نشد؛ مسیر تقریبی آفلاین نمایش داده می‌شود.'
            : 'مسیریابی ناموفق: $reason\nمسیر تقریبی آفلاین نمایش داده می‌شود.',
        icon: Icons.cloud_off_rounded,
        colors: const [Color(0xFFFFB74D), Color(0xFFE5834B)],
        duration: reason == null ? const Duration(seconds: 3) : const Duration(seconds: 7),
      );
    } else if (offlineFailReason == null && routingService.lastError != null) {
      // مسیر از گراف آفلاین موفق آمد (سرور آنلاین در دسترس نبود، ولی نیازی
      // به مسیر تقریبیِ خط‌مستقیم هم نشد) — کاربر را مطلع کن که این یک مسیر
      // واقعی روی جاده‌هاست، نه فقط تقریبی.
      _showGlassNotice(
        'بدون اینترنت — مسیر از نقشه‌ی آفلاین دانلودشده محاسبه شد.',
        icon: Icons.offline_pin_rounded,
        colors: const [AppColors.homeAccent, AppColors.subAccentA],
        duration: const Duration(seconds: 4),
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

  /// وقتی کاربر خودش نقشه را لمس/پن/چرخش می‌دهد صدا زده می‌شود.
  ///
  /// نکته‌ی مهم (رفع باگ «پیکان قفل نمی‌شود به GPS و موقع اسکرول غیب می‌شود»):
  /// در حالت followsCamera=false، مارکر خودرو مختصات صفحه‌اش را از
  /// `mapController.toScreenLocation()` می‌گیرد (نگاه کنید به vehicle_marker.dart).
  /// این تابع در maplibre_gl، وقتی دوربین هنوز tilt (پرسپکتیو سه‌بعدی، همان
  /// ۵۵ درجه‌ای که در حالت دنبال‌کردن استفاده می‌شود) دارد، در خیلی از
  /// نسخه‌ها مختصات کاملاً نادرست (خارج از صفحه) برمی‌گرداند. چون خودِ کاربر
  /// معمولاً همین لحظه (وسط اسکرول/پن) که دوربین را از حالت دنبال‌کردن خارج
  /// می‌کند tilt هنوز ۵۵ است، پیکان همان لحظه که باید ظاهر شود ناپدید می‌شد.
  /// راه‌حل: همین لحظه که کنترل دستی شروع می‌شود، دوربین را صاف (tilt: 0،
  /// بدون چرخش) می‌کنیم — دقیقاً رفتار استاندارد گوگل‌مپس/Waze هم هست
  /// (وقتی از حالت ناوبری بیرون می‌آیی، نقشه به حالت دوبعدی بالا-به-پایین
  /// برمی‌گردد) — و در همین حالت toScreenLocation مختصات درست برمی‌گرداند.
  void _takeManualCameraControl() {
    if (!_cameraFollowsVehicle) return; // قبلاً دستی شده؛ دوباره صاف نکن وگرنه پن کاربر را دور می‌زند
    setState(() => _cameraFollowsVehicle = false);
    final pos = ref.read(vehiclePositionProvider).value;
    if (_mapController != null && pos != null) {
      // نکته‌ی مهم (رفع باگ «پیکان هنگام اسکرول لحظه‌ای ناپدید می‌شود»):
      // قبلاً اینجا از animateCamera با ۳۰۰ میلی‌ثانیه استفاده می‌شد. در همان
      // ۳۰۰ میلی‌ثانیه که tilt از ۵۵ به ۰ در حال تغییر است، VehicleMarker
      // (که همزمان followsCamera=false شده و شروع به فراخوانی
      // toScreenLocation کرده) مختصات نادرست/خارج از صفحه می‌گرفت — دقیقاً
      // لحظه‌ای که کاربر شروع به اسکرول می‌کند. با moveCamera (بدون انیمیشن)
      // دوربین فوراً tilt:0 می‌شود، پس این پنجره‌ی زمانی خطرناک از بین
      // می‌رود و toScreenLocation از همان اولین فریم مختصات درست می‌دهد.
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.lat, pos.lng), zoom: 17, tilt: 0, bearing: 0),
        ),
      );
    }
  }

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
    // نکته‌ی مهم (رفع باگ «تا کنسل نکنی مسیریابی تمام نمی‌شود»): نسخه‌ی قبلی
    // این شرط را با «فاصله‌ی خط‌مستقیم تا نقطه‌ی دقیق مقصد (minDistance) < ۲۰
    // متر» چک می‌کرد. مشکل این‌جاست که نقطه‌ی مقصد (پینی که کاربر لمس‌طولانی
    // یا از جست‌وجو انتخاب کرده) در خیلی از مواقع خودِ ساختمان/نقطه‌ای کنار
    // جاده است، نه دقیقاً روی جاده — یعنی فاصله‌ی خط‌مستقیم تا آن پین معمولاً
    // بیشتر از ۲۰-۳۰ متر باقی می‌ماند حتی وقتی خودرو دقیقاً جلوی مقصد، روی
    // جاده، متوقف شده. نتیجه: minDistance هیچ‌وقت به زیر ۲۰ متر نمی‌رسید و
    // navigation تا ابد «در حال مسیریابی» می‌ماند. به‌جایش الان از
    // remainingDistance (فاصله‌ی باقیمانده روی خودِ مسیر، نه خط‌هوایی تا پین)
    // استفاده می‌کنیم که معیار قابل‌اعتمادتری برای «عملاً رسیده‌ای» است.
    if (!_arrivalHandled &&
        remainingDistance < 30 &&
        nearestInstructionIndex >= nav.route.instructions.length - 1) {
      _arrivalHandled = true;
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

class _GpsWarningBanner extends ConsumerWidget {
  final LocationReadiness state;
  const _GpsWarningBanner({super.key, required this.state});

  String get _message {
    switch (state) {
      case LocationReadiness.serviceDisabled:
        return 'GPS دستگاه خاموش است. لطفاً آن را روشن کنید.';
      case LocationReadiness.permissionDenied:
        return 'برای ناوبری به مجوز موقعیت مکانی نیاز است. (ضربه بزنید تا دوباره بپرسیم)';
      case LocationReadiness.permissionDeniedForever:
        return 'مجوز موقعیت مکانی رد شده. برای فعال‌سازی از تنظیمات، ضربه بزنید.';
      case LocationReadiness.ready:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // نکته‌ی مهم (رفع باگ «اگه مجوز داده نشده بود اپ دیگه دوباره سوال
    // نمی‌کرد»): علاوه بر تلاش خودکار در gps_providers.dart (هر بار اپ
    // resume می‌شود)، این بنر حالا خودش هم قابل ضربه‌زدن است تا کاربر
    // بتواند فوراً و دستی هم دوباره درخواست مجوز/تنظیمات را باز کند، بدون
    // این‌که منتظر رصد خودکار بماند.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: state == LocationReadiness.ready
          ? null
          : () => ref.read(retryLocationPermissionProvider)(),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
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
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2))],
                ),
              ),
              const Text(
                'km/h',
                style: TextStyle(
                  color: Color(0xFFDFE3E6),
                  fontSize: 13,
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
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      instruction.text,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
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
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 13),
          ),
        ],
      ),
    );
  }
}


