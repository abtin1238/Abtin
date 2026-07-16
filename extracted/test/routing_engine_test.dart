import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:abtin_navigator/features/navigation/data/offline_map_data.dart';
import 'package:abtin_navigator/features/navigation/domain/entities/route_info.dart';
import 'package:abtin_navigator/features/routing/data/offline_routing_engine.dart';
import 'package:abtin_navigator/features/routing/data/kalman_filter.dart';
import 'package:abtin_navigator/core/services/routing_service.dart';
import 'package:abtin_navigator/core/ai/smart_route_advisor.dart';
import 'package:abtin_navigator/core/deeplink/deeplink_parser.dart';
import 'package:abtin_navigator/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineRoutingEngine A*', () {
    late OfflineRoutingEngine engine;
    late OfflineCity city;

    setUp(() {
      city = buildTehranSampleCity();
      engine = OfflineRoutingEngine();
      engine.loadGraph(city.nodes, city.adjacency);
    });

    test('graph loads with expected node count', () {
      expect(engine.isLoaded, isTrue);
      expect(engine.nodeCount, city.nodes.length);
      expect(engine.nodeCount, greaterThan(100));
    });

    test('calculates a non-empty route between two nodes', () {
      final origin = city.nodes.first.position;
      final destination = city.nodes.last.position;
      final route = engine.calculateRoute(origin, destination);
      expect(route, isNotNull);
      expect(route!.polyline.length, greaterThan(1));
      expect(route.distanceMeters, greaterThan(0));
      expect(route.steps, isNotEmpty);
      expect(route.mode, TravelMode.car);
    });

    test('shortest preference tends to lower or equal distance', () {
      final a = city.nodes[10].position;
      final b = city.nodes[80].position;
      final fast = engine.calculateRoute(
        a,
        b,
        preference: RoutePreference.fastest,
      );
      final short = engine.calculateRoute(
        a,
        b,
        preference: RoutePreference.shortest,
      );
      expect(fast, isNotNull);
      expect(short, isNotNull);
      expect(
        short!.distanceMeters,
        lessThanOrEqualTo(fast!.distanceMeters * 1.05),
      );
    });
  });

  group('RoutingService offline-first', () {
    test('route works without network', () async {
      final service = RoutingService();
      await service.ensureOfflineGraphLoaded();
      final route = await service.route(
        const LatLng(35.7450, 51.4000),
        const LatLng(35.7600, 51.4200),
      );
      expect(route.polyline, isNotEmpty);
      expect(route.duration.inSeconds, greaterThan(0));
    });
  });

  group('GpsKalmanFilter', () {
    test('smooths and dead-reckons', () {
      final k = GpsKalmanFilter();
      final p1 = k.process(35.75, 51.40, 5, speedMps: 10);
      final p2 = k.process(35.7501, 51.4001, 5, speedMps: 10);
      expect(p2.latitude, closeTo(p1.latitude, 0.01));
      final estimated = k.deadReckon(90, 10, 1000);
      expect(estimated.longitude, greaterThan(p2.longitude - 0.001));
    });
  });

  group('SmartRouteAdvisor', () {
    test('predicts positive travel time', () {
      const advisor = SmartRouteAdvisor();
      final d = advisor.predictTravelTime(
        distanceMeters: 5000,
        mode: TravelMode.car,
        now: DateTime(2026, 1, 1, 8),
      );
      expect(d.inMinutes, greaterThan(3));
    });
  });

  group('DeeplinkParser', () {
    test('parses geo and abtin links', () {
      const parser = DeeplinkParser();
      final a = parser.parse('geo:35.7,51.4');
      expect(a, isNotNull);
      expect(a!.location.latitude, closeTo(35.7, 0.001));

      final b = parser.parse('abtin://navigate?lat=35.8&lon=51.5&title=Home');
      expect(b?.title, 'Home');
      expect(b?.location.longitude, closeTo(51.5, 0.001));
    });
  });

  group('AppDatabase memory', () {
    test('favorites CRUD and hazards seed', () async {
      final db = await AppDatabase.openInMemory();
      db.upsertFavorite(
        id: 'x1',
        title: 'خانه',
        lat: 35.7,
        lon: 51.4,
        category: 'home',
      );
      expect(db.allFavorites(), hasLength(1));
      expect(db.allHazards(), isNotEmpty);
      db.deleteFavorite('x1');
      expect(db.allFavorites(), isEmpty);
      db.close();
    });
  });
}
