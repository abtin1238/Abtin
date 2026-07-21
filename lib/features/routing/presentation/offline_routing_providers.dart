import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../data/routing_service.dart';
import '../data/offline_routing_service.dart';
import '../../map/presentation/destination_provider.dart';
import '../../gps/presentation/gps_providers.dart';

/// سرویس مسیریابی
final routingServiceProvider = Provider<RoutingService>((ref) {
  return RoutingService();
});

/// سرویس مسیریابی آفلاین
final offlineRoutingServiceProvider = Provider<OfflineRoutingService>((ref) {
  return OfflineRoutingService();
});

/// مدیریت داده‌های نقشه آفلاین
final offlineMapDataManagerProvider = Provider<OfflineMapDataManager>((ref) {
  return OfflineMapDataManager();
});

/// وضعیت مسیریابی فعال
enum NavigationState {
  idle, // بدون مسیریابی فعال
  calculating, // در حال محاسبه مسیر
  navigating, // مسیریابی فعال
  error, // خطا در محاسبه مسیر
}

/// اطلاعات مسیریابی فعال
class ActiveNavigation {
  final RouteInfo route;
  final NavigationState state;
  final int currentInstructionIndex;
  final double remainingDistanceKm;
  final double distanceToNextManeuverM; // فاصله تا پیچ بعدی (متر)
  final String? errorMessage;
  final bool isOfflineRoute; // آیا این مسیر از سرویس آفلاین است؟

  const ActiveNavigation({
    required this.route,
    this.state = NavigationState.navigating,
    this.currentInstructionIndex = 0,
    required this.remainingDistanceKm,
    this.distanceToNextManeuverM = 0,
    this.errorMessage,
    this.isOfflineRoute = false,
  });

  ActiveNavigation copyWith({
    RouteInfo? route,
    NavigationState? state,
    int? currentInstructionIndex,
    double? remainingDistanceKm,
    double? distanceToNextManeuverM,
    String? errorMessage,
    bool? isOfflineRoute,
  }) {
    return ActiveNavigation(
      route: route ?? this.route,
      state: state ?? this.state,
      currentInstructionIndex: currentInstructionIndex ?? this.currentInstructionIndex,
      remainingDistanceKm: remainingDistanceKm ?? this.remainingDistanceKm,
      distanceToNextManeuverM: distanceToNextManeuverM ?? this.distanceToNextManeuverM,
      errorMessage: errorMessage ?? this.errorMessage,
      isOfflineRoute: isOfflineRoute ?? this.isOfflineRoute,
    );
  }

  /// دستور فعلی
  RouteInstruction get currentInstruction {
    if (currentInstructionIndex < route.instructions.length) {
      return route.instructions[currentInstructionIndex];
    }
    return route.instructions.last;
  }

  /// آیا به مقصد رسیده‌ایم؟
  bool get hasArrived => currentInstructionIndex >= route.instructions.length - 1;
}

/// Provider برای مسیریابی فعال
class ActiveNavigationNotifier extends StateNotifier<ActiveNavigation?> {
  ActiveNavigationNotifier() : super(null);

  void setNavigation(ActiveNavigation nav) {
    state = nav;
  }

  void updateProgress(int instructionIndex, double remainingDistance,
      {double? distanceToNextManeuverM}) {
    if (state != null) {
      state = state!.copyWith(
        currentInstructionIndex: instructionIndex,
        remainingDistanceKm: remainingDistance,
        distanceToNextManeuverM: distanceToNextManeuverM,
      );
    }
  }

  void clear() {
    state = null;
  }
}

final activeNavigationProvider = StateNotifierProvider<ActiveNavigationNotifier, ActiveNavigation?>((ref) {
  return ActiveNavigationNotifier();
});

/// محاسبه مسیر از موقعیت فعلی به مقصد انتخاب‌شده
/// 
/// این provider سه سطح fallback را پشتیبانی می‌کند:
/// 1. OSRM محلی (اگر فعال باشد)
/// 2. OSRM عمومی آنلاین
/// 3. خط مستقیم تقریبی
final calculateRouteProvider = FutureProvider.autoDispose<RouteInfo?>((ref) async {
  final destination = ref.watch(selectedDestinationProvider);
  final vehiclePosition = ref.watch(vehiclePositionProvider).value;
  
  if (destination == null || vehiclePosition == null) {
    return null;
  }

  final offlineRoutingService = ref.read(offlineRoutingServiceProvider);
  
  return await offlineRoutingService.calculateRoute(
    origin: LatLng(vehiclePosition.lat, vehiclePosition.lng),
    destination: destination.point,
  );
});

/// محاسبه مسیر با ترجیح آفلاین کامل
/// 
/// این provider فقط سرور محلی OSRM را امتحان می‌کند
final calculateOfflineRouteOnlyProvider = FutureProvider.autoDispose<RouteInfo?>((ref) async {
  final destination = ref.watch(selectedDestinationProvider);
  final vehiclePosition = ref.watch(vehiclePositionProvider).value;
  
  if (destination == null || vehiclePosition == null) {
    return null;
  }

  final offlineRoutingService = ref.read(offlineRoutingServiceProvider);
  
  return await offlineRoutingService.calculateRoute(
    origin: LatLng(vehiclePosition.lat, vehiclePosition.lng),
    destination: destination.point,
    useLocalOnly: true, // فقط محلی
  );
});

/// بررسی دسترسی به سرور OSRM محلی
final osrmAvailabilityProvider = FutureProvider<bool>((ref) async {
  final offlineRoutingService = ref.read(offlineRoutingServiceProvider);
  return await offlineRoutingService.isLocalOsrmAvailable();
});

/// اطلاعات آمار سرویس مسیریابی آفلاین
final osrmStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final offlineRoutingService = ref.read(offlineRoutingServiceProvider);
  return offlineRoutingService.getCacheStats();
});

/// فهرست نقشه‌های دانلود‌شده
final downloadedMapsProvider = Provider<List<DownloadedMapData>>((ref) {
  final mapManager = ref.read(offlineMapDataManagerProvider);
  return mapManager.getDownloadedMaps();
});

/// Provider برای دانلود نقشه‌های جدید
final downloadMapProvider = FutureProvider.autoDispose.family<bool, (String, String)>((ref, args) async {
  final (regionName, downloadUrl) = args;
  final mapManager = ref.read(offlineMapDataManagerProvider);
  return await mapManager.downloadMapData(regionName, downloadUrl);
});
