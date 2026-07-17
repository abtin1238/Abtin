import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_notification_banner.dart';
import '../../data/navigation_controller.dart';
import '../widgets/maneuver_banner.dart';
import '../widgets/speedometer.dart';
import '../widgets/car_marker.dart';
import '../widgets/nav_compass.dart';
import '../widgets/online_map_view.dart';
import '../widgets/lane_guidance.dart';

/// نمای اصلی ناوبری: نقشه‌ی **آفلاین/کَش‌شدهٔ تمام‌صفحه** (OpenStreetMap)
/// + نوار مانورِ داینامیک (فقط هنگام ناوبری) + قطب‌نما + سرعت‌سنجِ واقعیِ داینامیک
/// + دکمه‌ی موقعیت. با **لمسِ طولانیِ** هر نقطه روی نقشه، مسیریابیِ زنده به
/// آن نقطه (از طریق موتور آفلاین A* روی گرافِ واقعیِ جاده‌ها) آغاز می‌شود.
class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  bool _routing = false;

  Future<void> _onLongPress(LatLng point) async {
    if (_routing) return;
    setState(() => _routing = true);
    final notifier = ref.read(appNotificationProvider.notifier);
    notifier.show('در حال محاسبه‌ی مسیر...', type: AppNotifyType.loading);

    try {
      final nav = ref.read(navigationControllerProvider);
      final origin = nav.position ?? defaultMapCenter;
      final routingService = ref.read(routingServiceProvider);
      final route = await routingService.route(origin, point);

      final ok =
          ref.read(navigationControllerProvider.notifier).startRoute(route);
      if (!ok) {
        notifier.show('مسیری تا این نقطه یافت نشد', type: AppNotifyType.error);
        return;
      }
      notifier.show(
        'مسیر ${route.distanceLabel} · ${route.durationLabel}',
        type: AppNotifyType.success,
      );
    } catch (e) {
      notifier.show('خطا در دریافت مسیر از سرویسِ آنلاین',
          type: AppNotifyType.error);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routing = ref.watch(routingSettingsProvider);
    final nav = ref.watch(navigationControllerProvider);
    final routeColor = AppColors.routeColors[routing.routeColorIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // فاصله‌ی امن از نوار ناوبریِ شناورِ پایین (سرعت‌سنج/دکمه‌ی موقعیت زیر منو نروند).
    final double navBarClearance =
        96 + MediaQuery.of(context).padding.bottom * 0.4;

    final camera = nav.position ?? defaultMapCenter;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0D1420),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // ---- نقشه‌ی آفلاین/کَش‌شدهٔ تمام‌صفحه ----
            Positioned.fill(
              child: OnlineMapView(
                camera: camera,
                headingDeg: nav.headingDeg,
                routePolyline: nav.routePolyline,
                destination: nav.destination,
                routeColor: routeColor,
                isDark: isDark,
                followCamera: nav.isNavigating,
                vehicle: routing.showVehicle
                    ? CarMarker(
                        headingDeg: nav.isNavigating ? 0 : nav.headingDeg,
                        headlights: routing.headlightsAtNight && isDark,
                      )
                    : null,
                onLongPressLatLng: _onLongPress,
                offlineService: ref.watch(offlineMapDownloadServiceProvider),
              ),
            ),

            // ---- نوار مانورِ داینامیک: فقط هنگام ناوبری ----
            if (nav.isNavigating && nav.nextManeuver != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    ManeuverBanner(
                      state: nav,
                      onClose: () => ref
                          .read(navigationControllerProvider.notifier)
                          .stopNavigation(),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: LaneGuidanceBar(
                        lanes: [0, 0, 1],
                        exitLabel: 'خط پیشنهادی',
                      ),
                    ),
                  ],
                ),
              ),

            // ---- نوارِ هشدار (فقط دوربینِ کنترلِ سرعت و سرعت‌گیر) ----
            if (nav.hazardType != null)
              Positioned(
                top: MediaQuery.of(context).padding.top +
                    (nav.isNavigating ? 168 : 62),
                left: 12,
                right: 12,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _HazardWarning(
                    type: nav.hazardType!,
                    title: nav.hazardTitle ?? '',
                  ),
                ),
              ),

            // ---- قطب‌نما (راست) ----
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  (nav.isNavigating ? 176 : 70),
              right: 16,
              child: NavCompass(headingDeg: nav.headingDeg),
            ),

            // ---- سرعت‌سنج (همیشه ثابتِ سمتِ چپ) + تابلوی محدودیتِ کوچک‌ترِ زیرِ آن ----
            Positioned(
              bottom: navBarClearance,
              left: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Speedometer(
                    speed: nav.currentSpeedKmh,
                    overLimit: nav.isOverLimit,
                  ),
                  // تابلوی محدودیتِ داینامیک (کوچک‌تر، دقیقاً زیرِ سرعت‌سنج).
                  if (nav.shouldShowSpeedLimit && nav.speedLimitKmh != null) ...[
                    const SizedBox(height: 8),
                    SpeedLimitSign(limit: nav.speedLimitKmh!, size: 54),
                  ],
                ],
              ),
            ),

            // ---- دکمه‌ی موقعیت من (پایین راست) ----
            Positioned(
              bottom: navBarClearance + 4,
              right: 16,
              child: _LocationButton(
                onTap: () => ref
                    .read(appNotificationProvider.notifier)
                    .show('موقعیت شما در مرکز نقشه است',
                        type: AppNotifyType.info,
                        duration: const Duration(seconds: 1)),
              ),
            ),

            // توجه: دکمه‌ی قرمزِ ضربدردارِ سمتِ چپ حذف شد؛ توقفِ ناوبری از طریقِ
            // دکمه‌ی بستنِ (X) روی نوارِ مانورِ بالا انجام می‌شود.
          ],
        ),
      ),
    );
  }
}

/// کارتِ هشدار — فقط برای دوربینِ کنترلِ سرعت و سرعت‌گیر.
class _HazardWarning extends StatelessWidget {
  final String type;
  final String title;
  const _HazardWarning({required this.type, required this.title});

  @override
  Widget build(BuildContext context) {
    final isCamera = type == 'speed_camera';
    final icon = isCamera ? Icons.speed_rounded : Icons.warning_amber_rounded;
    final accent = isCamera ? AppColors.danger : AppColors.goldSoft;
    final label = title.isNotEmpty
        ? title
        : (isCamera ? 'دوربین کنترل سرعت' : 'سرعت‌گیر');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF12161F).withOpacity(0.94),
        border: Border.all(color: accent.withOpacity(0.65), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.22), blurRadius: 16),
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}

/// دکمه‌ی شناور موقعیت من (پین سبز مطابق تصویر).
class _LocationButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LocationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF141B2B),
          border: Border.all(color: AppColors.borderDark),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12),
          ],
        ),
        child: const Icon(Icons.my_location_rounded,
            color: AppColors.primary, size: 26),
      ),
    );
  }
}

