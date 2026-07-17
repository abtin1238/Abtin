import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../navigation/domain/entities/route_info.dart';
import '../../routing/data/offline_routing_engine.dart';

/// بارگذاری گراف جاده از asset JSON (بسته نقشه آفلاین v1/v2).
class GraphAssetLoader {
  static const defaultAsset = 'assets/maps/tehran_sample_graph.json';

  static const _allModes = {
    TravelMode.car,
    TravelMode.truck,
    TravelMode.motorcycle,
    TravelMode.bicycle,
    TravelMode.pedestrian,
  };

  static Future<({List<GraphNode> nodes, Map<int, List<GraphEdge>> edges})>
      load([String asset = defaultAsset]) async {
    final raw = await rootBundle.loadString(asset);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final nodesJson = data['nodes'] as List<dynamic>;
    final edgesJson = data['edges'] as List<dynamic>;

    final nodes = <GraphNode>[];
    for (final n in nodesJson) {
      final m = n as Map<String, dynamic>;
      nodes.add(GraphNode(
        (m['id'] as num).toInt(),
        LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble()),
      ));
    }

    // reverse lookup for v1 graphs that only store undirected pairs once
    final reversePresent = <String>{};
    for (final e in edgesJson) {
      final m = e as Map<String, dynamic>;
      final a = (m['a'] as num).toInt();
      final b = (m['b'] as num).toInt();
      reversePresent.add('$a>$b');
    }

    final adj = <int, List<GraphEdge>>{};

    void push(
      int from,
      int to,
      double meters,
      double speed,
      Set<TravelMode> modes,
    ) {
      (adj[from] ??= []).add(GraphEdge(
        to: to,
        distanceMeters: meters,
        speedKmh: speed,
        allowedModes: modes,
      ));
    }

    for (final e in edgesJson) {
      final m = e as Map<String, dynamic>;
      final a = (m['a'] as num).toInt();
      final b = (m['b'] as num).toInt();
      final meters = ((m['m'] as num?) ?? 50).toDouble();
      final speed = ((m['speed'] as num?) ?? 40).toDouble();
      final oneway = ((m['oneway'] as num?) ?? 0) == 1;
      final modes = _parseModes(m['modes']);

      push(a, b, meters, speed, modes);
      if (!oneway && !reversePresent.contains('$b>$a')) {
        push(b, a, meters, speed, modes);
      }
    }

    return (nodes: nodes, edges: adj);
  }

  static Set<TravelMode> _parseModes(dynamic raw) {
    if (raw is! List || raw.isEmpty) return _allModes;
    final out = <TravelMode>{};
    for (final item in raw) {
      final s = '$item'.toLowerCase();
      if (s == 'car' || s == 'driving') {
        out.add(TravelMode.car);
      } else if (s == 'truck') {
        out.add(TravelMode.truck);
      } else if (s == 'motorcycle' || s == 'bike_motor') {
        out.add(TravelMode.motorcycle);
      } else if (s == 'bicycle' || s == 'bike') {
        out.add(TravelMode.bicycle);
      } else if (s == 'pedestrian' || s == 'foot' || s == 'walk') {
        out.add(TravelMode.pedestrian);
      }
    }
    return out.isEmpty ? _allModes : out;
  }
}
