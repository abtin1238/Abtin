import 'package:latlong2/latlong.dart';

import '../../features/maps/data/graph_asset_loader.dart';
import '../../features/maps/data/graph_registry.dart';
import '../../features/navigation/data/offline_map_data.dart';
import '../../features/navigation/domain/entities/route_info.dart';
import '../../features/routing/data/offline_routing_engine.dart';
import '../ai/smart_route_advisor.dart';
import '../native/native_routing_bridge.dart';

/// سرویس مسیریابی **آفلاین‌اول**.
///
/// ترتیب:
/// ۱) موتور نیتیو GraphHopper/Valhalla (در صورت موجود)
/// ۲) موتور A* محلی روی گراف JSON / نمونه تهران
class RoutingService {
  RoutingService({
    OfflineRoutingEngine? engine,
    SmartRouteAdvisor? advisor,
    NativeRoutingBridge? native,
  })  : _engine = engine ?? OfflineRoutingEngine(),
        _advisor = advisor ?? const SmartRouteAdvisor(),
        _native = native ?? NativeRoutingBridge();

  final OfflineRoutingEngine _engine;
  final SmartRouteAdvisor _advisor;
  final NativeRoutingBridge _native;
  bool _ready = false;
  Future<void>? _loading;

  bool get isReady => _ready;
  OfflineRoutingEngine get engine => _engine;
  NativeRoutingBridge get native => _native;

  /// بارگذاری گراف — ترجیحاً از asset JSON، وگرنه نمونهٔ کد.
  Future<void> ensureOfflineGraphLoaded() async {
    if (_ready && _engine.isLoaded) return;
    if (_loading != null) {
      await _loading;
      return;
    }
    _loading = _loadGraph();
    try {
      await _loading;
    } finally {
      _loading = null;
    }
  }

  String _activeGraphId = GraphRegistry.defaultPackage.id;

  String get activeGraphId => _activeGraphId;

  /// بارگذاری / تعویض گراف استان.
  Future<void> loadProvinceGraph(String packageId) async {
    final pkg = GraphRegistry.byId(packageId) ?? GraphRegistry.defaultPackage;
    final g = await GraphAssetLoader.load(pkg.assetPath);
    _engine.loadGraph(g.nodes, g.edges);
    _activeGraphId = pkg.id;
    _ready = _engine.isLoaded;
  }

  Future<void> _loadGraph() async {
    try {
      // پیش‌فرض: تهران متراکم v2؛ استان‌ها از GraphRegistry
      final pkg = GraphRegistry.defaultPackage;
      final g = await GraphAssetLoader.load(pkg.assetPath);
      _engine.loadGraph(g.nodes, g.edges);
      _activeGraphId = pkg.id;
      _ready = _engine.isLoaded;
      if (_ready) return;
    } catch (_) {
      // fallback below
    }
    try {
      final g = await GraphAssetLoader.load();
      _engine.loadGraph(g.nodes, g.edges);
      _ready = _engine.isLoaded;
      if (_ready) return;
    } catch (_) {}
    final city = buildTehranSampleCity();
    _engine.loadGraph(city.nodes, city.adjacency);
    _ready = _engine.isLoaded;
  }

  void loadGraph(List<GraphNode> nodes, Map<int, List<GraphEdge>> edges) {
    _engine.loadGraph(nodes, edges);
    _ready = _engine.isLoaded;
  }

  /// محاسبه مسیر کاملاً آفلاین (با fallback نیتیو).
  Future<RouteInfo> route(
    LatLng origin,
    LatLng destination, {
    TravelMode mode = TravelMode.car,
    RoutePreference preference = RoutePreference.fastest,
    bool applySmartEta = true,
  }) async {
    // ۱) نیتیو
    final nativeRoute = await _native.route(
      origin: origin,
      destination: destination,
      mode: mode,
      preference: preference,
    );
    if (nativeRoute != null) {
      return applySmartEta
          ? _withSmartEta(nativeRoute, mode)
          : nativeRoute;
    }

    // ۲) A* محلی
    await ensureOfflineGraphLoaded();
    final result = _engine.calculateRoute(
      origin,
      destination,
      mode: mode,
      preference: preference,
    );
    if (result == null) {
      throw RoutingException('مسیری بین این دو نقطه یافت نشد (آفلاین)');
    }
    return applySmartEta ? _withSmartEta(result, mode) : result;
  }

  RouteInfo _withSmartEta(RouteInfo result, TravelMode mode) {
    final smartDuration = _advisor.predictTravelTime(
      distanceMeters: result.distanceMeters,
      mode: mode,
    );
    return RouteInfo(
      polyline: result.polyline,
      steps: result.steps,
      distanceMeters: result.distanceMeters,
      duration: smartDuration,
      mode: result.mode,
      preference: result.preference,
    );
  }

  /// تغییر مسیر خودکار هنگام خروج از مسیر.
  Future<RouteInfo?> reroute({
    required LatLng current,
    required LatLng destination,
    TravelMode mode = TravelMode.car,
    RoutePreference preference = RoutePreference.fastest,
  }) async {
    try {
      return await route(
        current,
        destination,
        mode: mode,
        preference: preference,
      );
    } catch (_) {
      return null;
    }
  }
}

class RoutingException implements Exception {
  final String message;
  RoutingException(this.message);
  @override
  String toString() => message;
}
