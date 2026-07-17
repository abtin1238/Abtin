import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../features/navigation/data/offline_map_data.dart';
import '../../features/routing/data/offline_routing_engine.dart';
import '../services/geocoding_service.dart';
import '../services/offline_map_download_service.dart';
import '../services/routing_service.dart';
import '../bootstrap.dart';
import '../services/tts_service.dart';
import '../../features/favorites/data/favorites_repository.dart';
import '../../features/search/data/offline_search_service.dart';
import '../ai/smart_route_advisor.dart';

/// ---- تم برنامه (روشن/تیره/خودکار) ----
final themeModeProvider =
    StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// ---- ایندکس ناوبری پایین (منو/علاقه‌مندی/جستجو/صدا/تنظیمات) ----
/// ترتیب در RTL از راست به چپ نمایش داده می‌شود؛ ایندکس منطقی ثابت است.
final bottomNavIndexProvider = StateProvider<int>((ref) => 0); // خانه (نمای ناوبری)

/// ---- تنظیمات صدا (صفحه‌ی صدا) ----
class VoiceSettings {
  final bool guideEnabled;
  final String selectedVoiceId;
  final double speechRate; // 0.5 .. 2.0
  final double volume; // 0 .. 1
  final double pitch; // -1 .. 1
  final bool announceSpeedLimit;
  final bool announceCameras;
  final bool announceHazards;
  final GuidanceVerbosity verbosity;

  const VoiceSettings({
    this.guideEnabled = true,
    this.selectedVoiceId = 'mahsa',
    this.speechRate = 1.0,
    this.volume = 0.8,
    this.pitch = 0.0,
    this.announceSpeedLimit = true,
    this.announceCameras = true,
    this.announceHazards = true,
    this.verbosity = GuidanceVerbosity.standard,
  });

  VoiceSettings copyWith({
    bool? guideEnabled,
    String? selectedVoiceId,
    double? speechRate,
    double? volume,
    double? pitch,
    bool? announceSpeedLimit,
    bool? announceCameras,
    bool? announceHazards,
    GuidanceVerbosity? verbosity,
  }) =>
      VoiceSettings(
        guideEnabled: guideEnabled ?? this.guideEnabled,
        selectedVoiceId: selectedVoiceId ?? this.selectedVoiceId,
        speechRate: speechRate ?? this.speechRate,
        volume: volume ?? this.volume,
        pitch: pitch ?? this.pitch,
        announceSpeedLimit: announceSpeedLimit ?? this.announceSpeedLimit,
        announceCameras: announceCameras ?? this.announceCameras,
        announceHazards: announceHazards ?? this.announceHazards,
        verbosity: verbosity ?? this.verbosity,
      );
}

enum GuidanceVerbosity { standard, detailed, summary }

class VoiceSettingsNotifier extends StateNotifier<VoiceSettings> {
  VoiceSettingsNotifier() : super(const VoiceSettings());

  void toggleGuide(bool v) => state = state.copyWith(guideEnabled: v);
  void selectVoice(String id) => state = state.copyWith(selectedVoiceId: id);
  void setRate(double v) => state = state.copyWith(speechRate: v);
  void setVolume(double v) => state = state.copyWith(volume: v);
  void setPitch(double v) => state = state.copyWith(pitch: v);
  void setSpeedLimit(bool v) => state = state.copyWith(announceSpeedLimit: v);
  void setCameras(bool v) => state = state.copyWith(announceCameras: v);
  void setHazards(bool v) => state = state.copyWith(announceHazards: v);
  void setVerbosity(GuidanceVerbosity v) =>
      state = state.copyWith(verbosity: v);
}

final voiceSettingsProvider =
    StateNotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
        (ref) => VoiceSettingsNotifier());

/// ---- تنظیمات مسیریابی (صفحه‌ی تنظیمات مسیریابی) ----
class RoutingSettings {
  final int routeColorIndex; // ایندکس در AppColors.routeColors
  final double routeIntensity; // 0..1 (شدت رنگ)
  final bool threeDMap; // طرح سه‌بعدی یا استاندارد
  final bool showVehicle;
  final bool headlightsAtNight;
  final bool alternativeRoutes;
  final bool laneGuidance;

  const RoutingSettings({
    this.routeColorIndex = 0,
    this.routeIntensity = 0.8,
    this.threeDMap = false,
    this.showVehicle = true,
    this.headlightsAtNight = true,
    this.alternativeRoutes = true,
    this.laneGuidance = true,
  });

  RoutingSettings copyWith({
    int? routeColorIndex,
    double? routeIntensity,
    bool? threeDMap,
    bool? showVehicle,
    bool? headlightsAtNight,
    bool? alternativeRoutes,
    bool? laneGuidance,
  }) =>
      RoutingSettings(
        routeColorIndex: routeColorIndex ?? this.routeColorIndex,
        routeIntensity: routeIntensity ?? this.routeIntensity,
        threeDMap: threeDMap ?? this.threeDMap,
        showVehicle: showVehicle ?? this.showVehicle,
        headlightsAtNight: headlightsAtNight ?? this.headlightsAtNight,
        alternativeRoutes: alternativeRoutes ?? this.alternativeRoutes,
        laneGuidance: laneGuidance ?? this.laneGuidance,
      );
}

class RoutingSettingsNotifier extends StateNotifier<RoutingSettings> {
  RoutingSettingsNotifier() : super(const RoutingSettings());
  void setColor(int i) => state = state.copyWith(routeColorIndex: i);
  void setIntensity(double v) => state = state.copyWith(routeIntensity: v);
  void set3D(bool v) => state = state.copyWith(threeDMap: v);
  void setShowVehicle(bool v) => state = state.copyWith(showVehicle: v);
  void setHeadlights(bool v) => state = state.copyWith(headlightsAtNight: v);
  void setAlternatives(bool v) => state = state.copyWith(alternativeRoutes: v);
  void setLaneGuidance(bool v) => state = state.copyWith(laneGuidance: v);
}

final routingSettingsProvider =
    StateNotifierProvider<RoutingSettingsNotifier, RoutingSettings>(
        (ref) => RoutingSettingsNotifier());

/// ---- شهرِ آفلاین (گرافِ جاده‌ای + داده‌های رندرِ نقشه) ----
/// یک‌بار ساخته و در کلِ برنامه به اشتراک گذاشته می‌شود. کاملاً محلی/آفلاین.
final offlineCityProvider =
    Provider<OfflineCity>((ref) => buildTehranSampleCity());

/// ---- موتورِ مسیریابیِ آفلاین (A*) که گرافِ شهر در آن بارگذاری شده ----
/// (نگه‌داشته‌شده صرفاً برای تست‌های واحدِ موجود؛ نمای زنده‌ی برنامه دیگر
/// از این موتور استفاده نمی‌کند و به‌جای آن از [routingServiceProvider]
/// روی نقشه‌ی آنلاینِ واقعی مسیر می‌گیرد.)
final offlineRoutingEngineProvider = Provider<OfflineRoutingEngine>((ref) {
  final city = ref.watch(offlineCityProvider);
  final engine = OfflineRoutingEngine();
  engine.loadGraph(city.nodes, city.adjacency);
  return engine;
});

/// ---- سرویسِ جستجوی آفلاین POI + اختیاری ----
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

/// ---- سرویسِ مسیریابیِ آفلاین ----
/// سرویس مسیریابی آفلاین (در main با bootstrap override می‌شود).
final routingServiceProvider = Provider<RoutingService>((ref) {
  return RoutingService();
});

/// موتور جستجوی آفلاین POI
final offlineSearchServiceProvider = Provider<OfflineSearchService>((ref) {
  return OfflineSearchService();
});

/// مخزن علاقه‌مندی‌ها روی SQLite رمزنگاری‌شده
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(appDatabaseProvider));
});

/// مشاور مسیر هوشمند آفلاین
final smartRouteAdvisorProvider = Provider<SmartRouteAdvisor>((ref) {
  return const SmartRouteAdvisor();
});

/// ---- مرکزِ پیش‌فرضِ نقشه در حالتِ بی‌کار (تا دریافتِ GPS واقعی) ----
const LatLng defaultMapCenter = LatLng(35.7219, 51.4056); // تهران

/// ---- سرویسِ دانلودِ نقشه‌ی آفلاین (برای صفحه‌ی تنظیمات) ----
final offlineMapDownloadServiceProvider =
    Provider<OfflineMapDownloadService>((ref) {
  return OfflineMapDownloadService();
});


/// TTS سراسری (از bootstrap)
final ttsServiceProvider = Provider<TtsService>((ref) {
  return ref.watch(bootstrapTtsProvider);
});
