import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/location_permission_flow.dart';
import '../data/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.dispose);
  return service;
});

/// وضعیت آماده‌بودن GPS (مجوز + سرویس روشن). صفحه‌ی اصلی این را در initState
/// بررسی می‌کند و در صورت نیاز پیام مناسب نشان می‌دهد.
final locationReadinessProvider = FutureProvider<LocationReadiness>((ref) async {
  final result = await LocationPermissionFlow.ensureReady();
  if (result == LocationReadiness.ready) {
    ref.read(locationServiceProvider).start();
  }
  return result;
});

/// استریم موقعیت هموارشده‌ی خودرو — منبع اصلی برای مارکر و دوربین نقشه.
final vehiclePositionProvider = StreamProvider<VehiclePosition>((ref) {
  // اطمینان از این‌که سرویس GPS استارت خورده
  ref.watch(locationReadinessProvider);
  return ref.watch(locationServiceProvider).stream;
});
