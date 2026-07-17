import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:abtin_navigator/core/deeplink/deeplink_parser.dart';
import 'package:abtin_navigator/core/services/routing_service.dart';
import 'package:abtin_navigator/features/navigation/domain/entities/route_info.dart';
import 'package:abtin_navigator/features/voice/data/vosk_stt_service.dart';
import 'package:abtin_navigator/features/routing/data/offline_routing_engine.dart';
import 'package:abtin_navigator/features/navigation/data/offline_map_data.dart';
import 'package:abtin_navigator/core/database/app_database.dart';
import 'package:abtin_navigator/core/ai/smart_route_advisor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline complete stack', () {
    test('RoutingService routes offline without network', () async {
      final s = RoutingService();
      await s.ensureOfflineGraphLoaded();
      final r = await s.route(
        const LatLng(35.745, 51.40),
        const LatLng(35.76, 51.42),
      );
      expect(r.polyline.length, greaterThan(1));
      expect(r.distanceMeters, greaterThan(0));
    });

    test('A* engine from sample city', () {
      final city = buildTehranSampleCity();
      final engine = OfflineRoutingEngine()
        ..loadGraph(city.nodes, city.adjacency);
      final r = engine.calculateRoute(
        city.nodes.first.position,
        city.nodes.last.position,
        preference: RoutePreference.shortest,
      );
      expect(r, isNotNull);
      expect(r!.steps, isNotEmpty);
    });

    test('Voice commands parse FA intents', () {
      expect(
        VoskSttService.parseCommand('توقف ناوبری').type,
        VoiceCommandType.stopNavigation,
      );
      expect(
        VoskSttService.parseCommand('برو به خانه').type,
        VoiceCommandType.navigateHome,
      );
      expect(
        VoskSttService.parseCommand('مسیر جایگزین').type,
        VoiceCommandType.reroute,
      );
    });

    test('Deeplink geo and abtin schemes', () {
      const p = DeeplinkParser();
      expect(p.parse('geo:35.7,51.4')?.location.latitude, closeTo(35.7, 1e-6));
      expect(
        p.parse('abtin://navigate?lat=35.8&lon=51.5&title=X')?.title,
        'X',
      );
    });

    test('Database favorites + hazards', () async {
      final db = await AppDatabase.openInMemory();
      db.upsertFavorite(id: 'a', title: 'خانه', lat: 35.7, lon: 51.4);
      expect(db.allFavorites(), hasLength(1));
      expect(db.allHazards(), isNotEmpty);
      db.close();
    });

    test('Smart advisor rush-hour ETA longer', () {
      const a = SmartRouteAdvisor();
      final rush = a.predictTravelTime(
        distanceMeters: 10000,
        mode: TravelMode.car,
        now: DateTime(2026, 1, 1, 8),
      );
      final night = a.predictTravelTime(
        distanceMeters: 10000,
        mode: TravelMode.car,
        now: DateTime(2026, 1, 1, 2),
      );
      expect(rush.inSeconds, greaterThan(night.inSeconds));
    });
  });
}
