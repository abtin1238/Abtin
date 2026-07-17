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

            // ---- قطب‌نما (راست) ----
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  (nav.isNavigating ? 176 : 70),
              right: 16,
              child: NavCompass(headingDeg: nav.headingDeg),
            ),

            // ---- سرعت‌سنج + تابلوی محدودیت (پایین چپ، واقعیِ داینامیک) ----
            Positioned(
              bottom: navBarClearance,
              left: 16,
              child: Row(
                children: [
                  Speedometer(
                    speed: nav.currentSpeedKmh,
                    overLimit: nav.isOverLimit,
                  ),
                  const SizedBox(width: 10),
                  if (nav.shouldShowSpeedLimit && nav.speedLimitKmh != null)
                    SpeedLimitSign(limit: nav.speedLimitKmh!),
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

            // ---- توقفِ ناوبری (وقتی مسیر فعال است) ----
            if (nav.isNavigating)
              Positioned(
                bottom: navBarClearance + 4,
                left: 16,
                child: _StopButton(
                  onTap: () => ref
                      .read(navigationControllerProvider.notifier)
                      .stopNavigation(),
                ),
              ),
          ],
        ),
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

/// دکمه‌ی شناور توقفِ ناوبری.
class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2B1414),
          border: Border.all(color: AppColors.danger.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12),
          ],
        ),
        child: const Icon(Icons.close_rounded,
            color: AppColors.danger, size: 26),
      ),
    );
  }
}
